#!/usr/bin/env sh

if [ "$(basename "$0")" = "configopts.sh" ]; then
  cat << HELPEOF
Usage: . $0
Parse ARGS according to a specification.
Redirects to util-linux's 'enhanced' getopt for most actual option parsing.

Source this file to access the 'parse_args' function and call it as such:

parse_args "\$@" < SPECFILE

or

parse_args "\$@" << EOF
spec...
...
EOF

any function defined in this script that doesn't begin with an underscore
is suitable/meant to be used by a calling script

Note: a pipe cannot be used to pass the spec to this function as it
sets up variables that must be able to be accessed afterwards
HELPEOF
  exit 1
fi

ensure_getopt() {
  if ! command -v getopt 1>/dev/null 2>&1; then
    1>&2 echo "getopt could not be found"
    exit 1
  fi

  error_code=0
  (unset GETOPT_COMPATIBLE; getopt --test) || error_code=$?
  if [ "$error_code" -ne 4 ]; then
    1>&2 echo "installed getopt is not the enhanced version, which is required"
    exit 1
  fi
}

########### CONSTANTS FOR POSIX ###########

NEWLINE=$(printf '\nx')
NEWLINE=${NEWLINE%x}
TAB=$(printf '\t')

########### UTILITIES ###########

repeatchar() { printf "%${2-}s" | tr ' ' "${1:- }"; }

check_varname() {
  # https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_235
  # > In the shell command language, a word consisting solely of underscores,
  # > digits, and alphabetics from the portable character set.
  # > The first character of a name is not a digit.
  # not technically specified but empty string is also invalid
  while [ "$#" -gt 0 ]; do
    case "$1" in "" | [!_a-zA-Z]* | *[!_0-9a-zA-Z]*)
      1>&2 echo "'$1': not a valid identifier"
      return 1
    esac
    shift
  done
}
# see https://unix.stackexchange.com/a/464963
readc() {
  check_varname "$@" || return 1
  while [ "$#" -gt 0 ]; do
    gradual_char=""
    while true; do
      # read one byte, using a work around for the fact that command
      # substitution strips trailing newline characters.
      c=$(dd bs=1 count=1 2> /dev/null; echo x)
      c=${c%x}

      # fail on EOF
      [ -z "$c" ] && return 1
      # succeed if a full character has been accumulated in the output
      # variable (using "wc -m" to count the number of characters).
      gradual_char="${gradual_char}$c"
      [ "$(printf %s "$gradual_char" | wc -m)" -gt 0 ] && break
    done
    eval "$1='$gradual_char'"
    shift
  done
}

escape_string() {
  while [ "$#" -gt 0 ]; do
    (
      escaped_string=$(printf "%sx" "$1" | sed -e "s/'/'\\\\''/g")
      # delimit strings with spaces, but don't append a trailing one
      printf "'%s'%s" "${escaped_string%x}" "${2+ }"
    )
    shift
  done
}

# TODO: other options (customise help/version options, etc.)

########### DISPLAYING HELP ###########

_displayoptionshelp() (
  MAX_OPTION_SPACE=40
  OPTION_DESCRIPTION_GAP=2
  MAX_DESCRIPTION_SPACE=40
  DESCRIPTION_INDENT=2

  formattedoptions=""
  requiredargexists=""
  while IFS=';' read -r short long requiredarg description; do
    case "$description" in "#"*)
      # hidden
      continue
    esac

    if [ -n "$short$long" ] && [ -n "$requiredarg" ]; then
      requiredargexists=1
    fi

    comma="${short:+${long:+, }}"
    comma="${comma:-${long:+  }}"
    optionalarg="${requiredarg%"${requiredarg#"?"}"}"
    requiredarg="${requiredarg#"$optionalarg"}"
    if [ -n "$short$long" ]; then
      argseparator=""
      test -z "$optionalarg" && argseparator=" "
      test -n "$long" && argseparator="="

      short="${short:+-$short}"
      short="${short:-${long:+  }}"
      long="${long:+--$long}"
      requiredarg="${requiredarg:+${optionalarg:+[}${argseparator}${requiredarg}${optionalarg:+]}}"
    else
      requiredarg="${requiredarg%...}"
    fi

    formattedoptions="${formattedoptions:+$formattedoptions$NEWLINE}  ${short}${comma}${long}${requiredarg}$TAB${description}"
  done

  test -n "$requiredargexists" && echo 'Mandatory arguments to long options are mandatory for short options too.'

  max_option_length="$(echo "$formattedoptions" |
    awk -F "$TAB" '
      length($1) > maxlen {
      maxlen = length($1)
      }
      END {
        print maxlen
      }
    '
  )"

  if [ "$MAX_OPTION_SPACE" -gt "$((max_option_length + OPTION_DESCRIPTION_GAP))" ]; then
    MAX_OPTION_SPACE="$((max_option_length + OPTION_DESCRIPTION_GAP))"
  fi

  echo "$formattedoptions" |
  while IFS="$TAB" read -r option description; do
    optionhelp="$(printf "%-$((MAX_OPTION_SPACE - OPTION_DESCRIPTION_GAP))s" "$option")"

    placeholder="$(repeatchar '@' "$((OPTION_DESCRIPTION_GAP + 1))")"
    firstline="$(printf "%-$((${#optionhelp} - 2))s" '')${placeholder}"
    secondline="$(printf "%-$((MAX_OPTION_SPACE + DESCRIPTION_INDENT))s" '')$description"

    fmteddescription=$(echo "$firstline$NEWLINE$secondline" | fmt -"$((MAX_OPTION_SPACE + MAX_DESCRIPTION_SPACE))" -t)
    fulloptionhelp="${optionhelp}$(repeatchar ' ' "$((OPTION_DESCRIPTION_GAP - 1))")${fmteddescription#*"$placeholder"}"
    echo "$fulloptionhelp"
  done
)

_displayusagehelp() (
  allusages="${customusages:+${customusages#"$NEWLINE"}}"
  # an extra newline shows that a usage exists even if it is empty
  usage_exists="${customusages:+${customusages%"$alluages"}}"
  if [ -z "${disabledefaultusage-}" ]; then
    positional_args=""
    while IFS=';' read -r short long requiredarg description; do
      if [ -z "${short}${long}" ]; then
        beforemulti="${requiredarg%...}"
        multi="${requiredarg#"$beforemulti"}"
        case "$beforemulti" in "?"*)
          beforemulti="[${beforemulti#"?"}]"
        esac
        positional_args="${positional_args:+$positional_args }$beforemulti$multi"
      fi
    done
    allusages="$positional_args${allusages:+$NEWLINE$allusages}"
    usage_exists=1
  fi
  if [ -n "$usage_exists$allusages" ]; then
    first=""
    printf '%s\n' "$allusages" |
    while read -r usage; do
      if [ -z "$first" ]; then
        prefix="Usage: $programname [OPTION]..."
        first=1
      else
        prefix="  or:  $programname [OPTION]..."
      fi
      echo "$prefix $usage"
    done
  fi
)

_displaydescriptionhelp() (
  test -n "${helpdescription-}" && echo "$helpdescription"
)
_displayextrainfohelp() (
  test -n "${helpextrainfo-}" && echo "$NEWLINE$helpextrainfo"
)
_displayposthelp() (
  test -n "${helpfooter-}" && echo "$NEWLINE$helpfooter"
)

_displayhelp() (
  printed=""
  usages="$(echo "$alloptions" | _displayusagehelp)"
  if [ -n "$usages" ]; then
    echo "$usages"
    printed=1
  fi
  ( _displaydescriptionhelp || test -n "$printed" ) &&
    # add gap if necessary
    echo
  echo "$alloptions" | _displayoptionshelp
  _displayextrainfohelp
  _displayposthelp
)

_displayversion() {
  printf '%s' "$versioninformation"
}

########### PROCESSING SPEC ###########

_processoption() {
  short=""
  case "$1" in ?,*)
    short="${1%,*}"
  esac
  rest="${1#"$short,"}"
  long="${rest%%=*}"
  requiredarg="${rest#"$long"}"
  case "$requiredarg" in
    =) requiredarg="ARG" ;;
    ="?") requiredarg="?ARG" ;;
    =...) requiredarg="ARG..." ;;
    ="?"...) requiredarg="?ARG..." ;;
    =*) requiredarg="${requiredarg#=}" ;;
  esac
  shift
  description="$*"

  optionalarg="${requiredarg%"${requiredarg#"?"}"}"
  argrequirement="${requiredarg:+:}${optionalarg:+:}"
  test -n "$short" && shortoptions="${shortoptions}${short}${argrequirement}"
  test -n "$long" && longoptions="${longoptions},${long}${argrequirement}"

  alloptions="${alloptions:+$alloptions$NEWLINE}${short};${long};${requiredarg};${description}"
}

_processusage() {
  customusages="${customusages-}$NEWLINE$1"
}

_processline() {
  case "$1" in
    "programname")
      programname="$2"
    ;;
    "option")
      # shellcheck disable=SC2086
      _processoption $2
    ;;
    "disable-default-help")
      disabledefaulthelp="true"
    ;;
    "usage")
      _processusage "$2"
    ;;
    "disable-default-usage")
      disabledefaultusage="true"
    ;;
    "description")
      helpdescription="$2"
    ;;
    "extrainfo")
      helpextrainfo="$2"
    ;;
    "footer")
      helpfooter="$2"
    ;;
    "version")
      versioninformation="$2"
    ;;
  esac
}

_processspec() {
  currentcommand=""
  currentargs=""
  while readc firstchar; do
    # readc sets $firstchar
    # shellcheck disable=SC2154
    case "$firstchar" in
      (@)
        _processline "$currentcommand" "$currentargs"
        read -r currentcommand currentargs
      ;;
      (*)
        IFS="" read -r extraargs
        [ "$firstchar" = "\\" ] && firstchar=""
        currentargs="${currentargs:+$currentargs$NEWLINE}$firstchar$extraargs"
      ;;
    esac
  done
  _processline "$currentcommand" "$currentargs"
  programname=$(get_programname)
}

########## PARSING ARGS ##########

# possibly shouldn't be 'public' but I can see it getting some use
getoptioninfo() {
  echo "$alloptions" |
  while IFS=';' read -r short long requiredarg description; do
    if [ "$1" = "-$short" ] || [ "$1" = "--$long" ]; then
      echo "${short};${long};${requiredarg}"
      return 0
    fi
  done
  return 1
}
optionhasrequiredarg() (
  # won't work correctly if requiredarg is just newlines
  # as they'll be stripped but ????
  optioninfo="$(getoptioninfo "$1")"
  test -n "${optioninfo#*;*;}"
  return
)

parse_args() {
  ensure_getopt

  shortoptions="h"
  longoptions="help"
  alloptions=""

  _processspec </dev/stdin

  if [ -z "${disabledefaulthelp-}" ]; then
    _processoption "h,help" "display this help and exit"
  fi
  if [ -n "${versioninformation-}" ]; then
    _processoption "v,version" "output version information and exit"
  fi

  ARGS="$(
    unset GETOPT_COMPATIBLE
    getopt \
      --shell sh \
      --name "$programname" \
      --options "$shortoptions" \
      --longoptions "$longoptions" \
      -- "$@"
  )" || {
    1>&2 echo "Try '$programname --help' for more information"
    exit 1
  }
  eval "set -- ${ARGS}"

  named_args=""
  positional_args=""

  named_args_finished=false
  while true; do
    option="${1-}"
    shift || break
    if $named_args_finished; then
      positional_args="$positional_args $(escape_string "$option")"
      continue
    fi
    case "$option" in
      (--) named_args_finished=true ;;
      (-? | --*)
        if [ -z "${disabledefaulthelp-}" ]; then
          case "$option" in -h | --help)
            _displayhelp
            exit 0
          esac
        fi
        if [ -n "${versioninformation-}" ]; then
          case "$option" in -v | --version)
            _displayversion
            exit 0
          esac
        fi
        if optionhasrequiredarg "$option"; then
          optionarg="$1"
          shift
        else
          optionarg=""
        fi
        named_args="$named_args $(escape_string "$option" "$optionarg")"
      ;;
      (*)
        1>&2 echo 'should not be possible :/ (provided getopt may be invalid)'
        exit 1
      ;;
    esac
  done
}

########## READING OPTIONS/ARGS ##########

_removequotedarg() {
  sed -e "
    # combine all lines into a single one:
    :loop;
    \$! {     # if not last line
      N;      # append next line to current
      b loop; # jump to :loop
    };
    # match intitial whitespace and the first quoted string,
    # removing them
    s/^[[:blank:]]*'[^']*\('\\\''[^']*\)*'//;
  "
#   s/
#     ^[[:blank:]]*
#     '
#     [^']*
#     \(
#       '\\\''
#       [^']*
#     \)*
#     '
#   /\1/
}
_extractquotedarg() {
  sed -e "
    # combine all lines into a single one:
    :loop;
    \$! {     # if not last line
      N;      # append next line to current
      b loop; # jump to :loop
    };
    # match intitial whitespace then capture the first quoted string
    # and match the rest of the text, replacing it with the capture
    s/^[[:blank:]]*\('[^']*\('\\\''[^']*\)*'\).*/\1/;
  "
#   s/
#     ^[[:blank:]]*
#     \(
#       '
#       [^']*
#       \(
#         '\\\''
#         [^']*
#       \)*
#       '
#     \)
#     .*
#   /\1/
}

readoption() {
  if [ "$#" -ne 2 ]; then
    1>&2 echo "readoption: exactly 2 args required but $# were supplied"
    return 1
  fi
  # no trailing whitespace
  test -z "$named_args" && return 1

  check_varname "$@"
  eval "$1=$(echo "$named_args" | _extractquotedarg)"
  named_args="$(echo "$named_args" | _removequotedarg)"
  eval "$2=$(echo "$named_args" | _extractquotedarg)"
  named_args="$(echo "$named_args" | _removequotedarg)"
}
readpositionalarg() {
  if [ "$#" -ne 1 ]; then
    1>&2 echo "readpositionalarg: exactly 1 arg required but $# were supplied"
    return 1
  fi
  # no trailing whitespace so it it's empty it's empty
  test -z "$positional_args" && return 1

  check_varname "$@"
  eval "$1=$(echo "$positional_args" | _extractquotedarg)"
  positional_args="$(echo "$positional_args" | _removequotedarg)"
}

readexactpositionalargs() {
  tryhelpexit=""
  while [ "$#" -gt 0 ]; do
    if ! readpositionalarg "$1"; then
      echoerr "missing $1 operand"
      tryhelpexit=true
    fi
    shift
  done
  if readpositionalarg extra_arg; then
    # readpositionalarg sets $extra_arg
    # (idk why shellcheck doesn't pick
    # this up automatically tbh)
    # shellcheck disable=SC2154
    echoerr "extra argument recieved: '$extra_arg'"
    tryhelpexit=true
  fi

  test -z "$tryhelpexit" || tryhelpexit
}

########## EXTRA PUBLIC UTILITIES ##########

# preferably I'd simulate the behaviour of coreutils:
# `cp --help` -> `Usage:  cp ...`
# `$(which cp) --help` -> `Usage:  /.../cp ...`
# but I just can't hack it :/

# use a shorter $0 if possible
get_better0() {
  scriptname="$(basename "$0")"
  scriptinPATH="$(command -v "$scriptname")"
  if [ -n "$scriptinPATH" ] && [ "$(realpath "$scriptinPATH")" = "$(realpath "$0")" ]; then
    # scriptname is in PATH and it points to the same place as the
    # one that is currently running so it's fine to use it instead
    printf '%s' "$scriptname"
  else
    printf '%s' "$0"
  fi
}

get_programname() {
  printf '%s' "${programname-$(get_better0)}"
}

echoerr() {
  >&2 echo "$(get_programname): ${1-an error occured}"
}

tryhelpexit() {
  >&2 echo "Try '$(get_programname) --help' for more information"
  exit 1
}
