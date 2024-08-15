#!/usr/bin/env bash

# TODO:
# add list-generations support

# shellcheck source=configopts.sh
source "${CONFIGOPTS_SCRIPT:-configopts.sh}" || {
  cat << 'EOF'
failed to source configopts!
to fix:
-    provide its path in $CONFIGOPTS_SCRIPT
- or put it in $PATH
- or put it in the current directory
EOF
  exit 1
}

whenoption() {
  cat << EOF
@option ,$1=?WHEN Specify when to $2: auto, never, always.
(defaults to auto without this flag, defaults to always when just --$1 is given)
@option ,no-$1 Alias of --$1=never
EOF
}
parse_whenoption() {
  check_varname "$1"
  case "$option" in --no-*)
    eval "$1=never"
    return 0
  esac
  case "$arg" in auto|never|always|"")
    eval "$1=\${arg:-always}"
    return 0
  esac
  echoerr "invalid value '$arg' for $option"
  tryhelpexit
}

parse_args "$@" << EOF
# due to re-execing, this gets messed up often
@programname $(basename "$0")
@description
Manage a nixos installation.

SUBCOMMANDS
  build - build a nixos configuration
  dry-build - evaluate a nixos configuration but don't build it
  repl - open a nixos configuration in 'nix repl'
  eval ATTR - evaluate ATTR from the flake of a nixos configuration
  run PROGRAM [ARGS]... - run PROGRAM from the flake of a nixos configuration
\
@option =SUBCOMMAND #

### SUBCOMMAND OPTIONS

# build
@option b,boot Install boot menu generation. Valid only for boot subcommand.
@option s,switch Switch to the new configuration. Valid only for boot subcommand.

# run
@option e,expr ATTR/PROGRAM is a nix expression in the repl context (ie. access to pkgs, hmConfig, etc.). Valid only for eval and run subcommands.

# eval
@option ,raw Output a string result without any quoting. Valid only for eval subcommand.
@option ,json Output a result (containign no functions) as json. Valid only for eval subcommand.

### NIXOS CONFIGURATION OPTIONS

@option f,flake=FLAKE Specify flake uri(s),
multiple can be delimited by newlines and the first valid one is used
(defaults to \$NIXOS_BUILD_FLAKE if set or /etc/nixos)

@option ,refattr=ATTR Adds flake reference attribute, ATTR, to the flake uri.
Should be of the form 'name=value' and percent encoded
@option ,ref=REF Alias of --refattr=ref=REF
@option ,rev=REV Alias of --refattr=rev=REV

@option n,name=NAME Specify configuration name
(defaults to \$NIXOS_BUILD_CONFIGURATION if set or the system hostname)

### OTHER OPTIONS

@option p,profile=NAME Specify name of profile to be used.
Uses '/nix/var/nix/profiles/system' when NAME == 'system', otherwise
uses '/nix/var/nix/profiles/system-profiles/NAME'
(defaults to 'system')

@option ,install-bootloader (re)install the bootloader as specified by the configuration

@option ,no-interactive Don't prompt for anything.
@option ,sudo-late Only prompt for the sudo password at the moment it is required.
@option ,no-sudo Don't use sudo.

$(whenoption "link" "produce result symlinks")
@option o,out-link=PATH Specify prefix for result symlinks (defaults to 'result')

$(whenoption "diff" "display a diff")
$(whenoption "print-info" "display info about what is happenning")

$(whenoption "sops-check" "check secrets.json with sops")

@option ,git-add run 'git add -AN' in flake src dir when appropriate

@option u,update=FLAKE Update FLAKE (or all flakes if FLAKE=all) before building
@option ,timeout=TIME Timeout password reading after TIMEOUT seconds
EOF

# for `set -e`
IN_NIXOS_BUILD_REEXEC=${IN_NIXOS_BUILD_REEXEC-}


flakes=${NIXOS_BUILD_FLAKE:-/etc/nixos}

actual_hostname=$(cat /proc/sys/kernel/hostname) ||
  actual_hostname=default
# ${..-..} over ${..:-..} is purposeful bc the empty string
# is _technically_ a valid name as it is a valid nix attr name
configuration=${NIXOS_BUILD_CONFIGURATION-$actual_hostname}

boot=
switch=

expr=

raw=
json=

refattrs=

profile=system

install_bootloader=

interactive=1
sudo_late=
sudo=1

link=auto
out_link=result
diff=auto
print_info=auto
sops_check=auto

git_add=

update_flakes=()
timeout=

while readoption option arg; do
  # readoption sets $arg
  # shellcheck disable=SC2154,SC2269
  arg=$arg

  argrequired() {
    test -n "$arg" || {
      echoerr "option '$option' requires an argument"
      tryhelpexit
    }
  }

  addrefattr() {
    argrequired
    test -n "$refattrs" && refattrs=$refattrs'&'
    refattrs=$refattrs$1
  }

  case "$option" in
    (-b | --boot) boot=1 ;;
    (-s | --switch) switch=1 ;;

    (-e | --expr) expr=1 ;;

    (--raw) raw=1 ;;
    (--json) json=1 ;;

    (-f | --flake) argrequired; flakes=$arg ;;

    (--refattr) addrefattr "$arg" ;;
    (--ref) addrefattr "ref=$arg" ;;
    (--rev) addrefattr "rev=$arg" ;;

    (-n | --name) configuration=$arg ;;
    (-p | --profile) argrequired; profile=$arg ;;

    (--install-bootloader) install_bootloader=1 ;;

    (--no-interactive) interactive= ;;
    (--sudo-late) sudo_late=1 ;;
    (--no-sudo) sudo= ;;

    (--link | --no-link) parse_whenoption link ;;
    (-o | --out-link) out_link=$arg ;;

    (--diff | --no-diff) parse_whenoption diff ;;
    (--print-info | --no-print-info) parse_whenoption print_info ;;

    (--sops-check | --no-sops-check) parse_whenoption sops_check ;;

    (--git-add) git_add=1 ;;

    (-u | --update) update_flakes+=("$arg") ;;

    (--timeout) timeout=$arg ;;

    (*) exit 1 ;;
  esac
done

readrequiredpositionalarg SUBCOMMAND

######### VALIDATE SUBCOMMANDS/FLAGS ##########

evalAttr=
runAttr=
runArgs=
case "$SUBCOMMAND" in
  build|dry-build|repl)
    # shellcheck disable=SC2119
    readexactpositionalargs
  ;;
  eval)
    readexactpositionalargs ATTR
    evalAttr=$ATTR
  ;;
  run)
    readrequiredpositionalarg PROGRAM
    runAttr=$PROGRAM
    readremainingpositionalargs runArgs
  ;;
  *)
    echoerr "'$SUBCOMMAND' is not a valid command"
    tryhelpexit
  ;;
esac

if [ "$SUBCOMMAND" != "build" ]; then
  test -n "$switch" && echoerr "'-s/--switch' only valid for the 'build' subcommand"
  test -n "$boot" && echoerr "'-b/--boot' only valid for the 'build' subcommand"
fi

if [ "$SUBCOMMAND" != "eval" ] && [ "$SUBCOMMAND" != "run" ]; then
  test -n "$expr" && echoerr "'-e/--expr' only valid for the 'eval' and 'run' subcommands"
fi

if [ "$SUBCOMMAND" != "eval" ]; then
  test -n "$raw" && echoerr "'--raw' only valid for the 'eval' subcommand"
  test -n "$json" && echoerr "'--json' only valid for the 'eval' subcommand"
fi

test -n "$raw" && test -n "$json" &&
  echoerr "'--raw' and '--json' are mutually exclusive"

test -z "$boot" && test -n "$install_bootloader" &&
  echoerr "'--install-bootloader' only valid for the '-b/--boot' option"

if [ "$profile" = "system" ]; then
  profile_path=/nix/var/nix/profiles/system
else
  profile_path=/nix/var/nix/profiles/system-profiles/$profile
fi

do_link=
case "$link:$SUBCOMMAND$boot$switch" in always:*|auto:build)
  do_link=1
esac

show_diff=
case "$diff:$SUBCOMMAND$boot$switch" in always:*|auto:build1*)
  show_diff=1
esac
show_info=1
case "$print_info:$SUBCOMMAND" in never:*|auto:run|auto:eval)
  show_info=
esac

do_sops_check=
case "$sops_check:$SUBCOMMAND$boot$switch" in always:*|auto:build1*)
  do_sops_check=1
esac

nix_options=(--option warn-dirty false)

config_attr=nixosConfigurations.\"$configuration\"
nix_repl_attrset='
  let
    nixosConfiguration = (__getFlake "flake").'"$config_attr"';
  in
  # pass inputs that would be available to a module
  {
    inherit nixosConfiguration;
    inherit (nixosConfiguration) config options pkgs lib;
    inherit (nixosConfiguration._module) specialArgs;
  } // nixosConfiguration._module.specialArgs
  # plus some home-manager stuff
  // {
    hmConfig = nixosConfiguration.config.home-manager.users."'"$USER"'";
  }
'

echoinfo() {
  if [ -n "$show_info" ]; then
    echo "$@"
  fi
}

NIX_EXEC=
_nix() {
  if [ -n "$NIX_EXEC" ]; then
    exec nix "${nix_options[@]}" "$@"
  else
    nix "${nix_options[@]}" "$@"
  fi
}

unset sudo_passkey
_sudo() {
  if [ -n "$sudo" ]; then
    if [ -n "$interactive" ]; then
      if
        ! sudo -vn 2>/dev/null && {
          [ -z "${sudo_passkey+x}" ] ||
          ! echo "$sudo_passkey" | sudo -Sv 2>/dev/null
        }
      then ensure_sudo
      fi
      sudo "$@"
    else
      echoinfo 'sudo required...'
      sudo -n "$@"
    fi
  else
    echoinfo "sudo required but disabled by '--no-sudo' so trying without..."
    "$@"
  fi
}

ensure_sudo() {
  if ! sudo -vn 2>/dev/null; then
    echo 'sudo password required...'
    while true; do
      if {
        printf %s "Password: "
        3</dev/tty read ${timeout:+-t "$timeout"} -u 3 -rs sudo_passkey
      }; then
        printf '\n'
        if printf %s "$sudo_passkey" | sudo -Sv 2>/dev/null; then
          break
        else
          echo 'Password incorrect, try again'
        fi
      else
        printf '\n'
        echoerr "timed out after '$timeout' seconds"
        exit 1
      fi
    done
  fi >/dev/tty
}

check_sudo_required() {
  if [ -n "$sudo" ] && [ -n "$boot$switch" ]; then
    echoinfo 'sudo will be required...'
    test -n "$interactive" && ensure_sudo
  fi
}

test -z "$sudo_late" && check_sudo_required

### ENSURE VALID FLAKE
get_flake_store_path() {
  _nix flake prefetch --json "$flake" |
  jq -r '.storePath'
}

flake_metadata=
get_flake_metadata() {
  _nix flake metadata --json "$flake"
}

rest_of_flakes=$flakes$'\n'
while true; do
  flake=${rest_of_flakes%%$'\n'*}
  rest_of_flakes=${rest_of_flakes#"$flake"$'\n'}
  if [ -n "$flake" ]; then
    if [ -n "$refattrs" ]; then
      case "$flake" in
        *'?'*) flake=$flake"&"$refattrs;;
        *) flake=$flake"?"$refattrs;;
      esac
    fi
    flake_store_path=$(get_flake_store_path) && break
  elif [ -z "$rest_of_flakes" ]; then
    echoerr "no flakes could be fetched"
    exit 1
  fi
done

echoinfo "Using nixos from flake at '$flake'"

flake_config_attr=$flake#$config_attr

######### PRE-REEXEC ACTIONS ##########

if [ -z "$IN_NIXOS_BUILD_REEXEC" ]; then

  if [ -n "$git_add" ]; then
    flake_metadata=$(get_flake_metadata) || exit 1
    flake_src_dir=$(printf %s "$flake_metadata" | jq -r '
      .resolved |
      if .type == "git" and (has("ref") or has("rev") | not) then
        .url
      else
        ""
      end
    ')
    flake_src_dir=${flake_src_dir#file://}
    flake_src_dir=${flake_src_dir#file:}

    _git() (
      cd "$flake_src_dir" && git "$@"
    )

    if
      [ -n "$flake_src_dir" ] &&
      # test for a git repo
      _git rev-parse --git-dir >/dev/null 2>&1
    then
      # track all non-ignored files (-A) to ensure new (as yet uncommited) files
      # are correctly copied to the store but don't actually stage them (-N)
      _git add -AN || {
        echoerr "failed to run 'git add -AN' but continuing..."
      }
    else
      echoerr "flake isn't a git repo, ignoring '--git-add'..."
    fi
  fi

  if [ "${#update_flakes[@]}" -gt 0 ]; then
    echo "Updating Flakes..."
    case "${update_flakes[*]}" in "all")
      update_flakes=()
    esac
    _nix flake update "${update_flakes[@]}" || exit 1
  fi

  if [ -n "$show_diff" ]; then
    # refetch flake even if git add already did so (just in case??)...
    flake_store_path=$(get_flake_store_path) || exit 1
    diff -r /etc/nixos-current-system-source "$flake_store_path" --exclude=".git" --color || true
  fi

fi

######### REEXEC ##########

# re-exec nixos if the configuration is going to be 'used'
# after being built to, for example, prevent getting stuck
# (if only temporarily) in a system with a broken nixos command
if [ -z "$IN_NIXOS_BUILD_REEXEC" ] && [ -n "$boot$switch" ]; then
  IN_NIXOS_BUILD_REEXEC=1 NIX_EXEC=1 _nix run "$flake_config_attr.pkgs.local.nixos" -- "$@"
fi

######### POST-REEXEC ACTIONS ##########

flake_secrets_json=$flake_store_path/secrets.json
  if [ -n "$do_sops_check" ] && [ -e "$flake_secrets_json" ]; then
  SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops --decrypt "$flake_secrets_json" >/dev/null || {
    echoerr "failed to decrypt secrets.json using sops"
    echoerr "use '--no-sops-check' if you know what you are doing"
    echoerr "otherwise use 'gen-sops-secrets' to properly generate an age key and/or secrets.json file"
    tryhelpexit
  }
fi

######### SETUP TMPDIR ##########

tmpDir=$(mktemp -d rebuild-XXXXXX) || {
  echoerr "mktemp failed, cannot continue"
  exit 1
}
cleanup() {
  rm -rf "$tmpDir"
}
trap cleanup EXIT

######### RUN SUBCOMMAND ##########

case "$SUBCOMMAND" in
  build)
    echo "Building NixOS configuration: '$configuration'..."
    if [ -n "$do_link" ]; then
      result_path=$out_link
    else
      result_path=$tmpDir/result
    fi
    _nix build --out-link "$result_path" "$flake_config_attr.config.system.build.toplevel" || exit 1
    echo "Successfully built the configuration"
    configuration_path=$(readlink -f "$result_path") || exit 1

    if [ -n "$boot" ]; then
      _sudo mkdir -p -m 0755 "$(dirname "$profile_path")" || exit 1
      # TODO: figure out how to do the same with 'nix profile'
      _sudo nix-env -p "$profile_path" --set "$configuration_path" || exit 1
      echo "Successfully made the new configuration the boot default"
    fi

    if [ -n "$boot$switch" ]; then
      # for future specialisation support
      switch_to_configuration=$configuration_path/bin/switch-to-configuration

      # see nixos-rebuild source
      run_in_env=(
        _sudo
        systemd-run
        -E LOCALE_ARCHIVE
        -E NIXOS_INSTALL_BOOTLOADER="$install_bootloader"
        --collect
        --no-ask-password
        --pipe
        --quiet
        --same-dir
        --service-type=exec
        --unit=nixos-switch-to-configuration
        --wait
      )

      if ! "${run_in_env[@]}" true; then
        1>&2 echo "systemd-run failed, falling back to env..."
        run_in_env=(
          _sudo
          env
          --ignore-environment
          LOCALE_ARCHIVE="$LOCALE_ARCHIVE"
          NIXOS_INSTALL_BOOTLOADER="$install_bootloader"
        )
      fi

      case "$boot:$switch" in
        1:1) action=switch ;;
        1:) action=boot ;;
        :1) action="test" ;; # quoted for shellcheck
      esac

      "${run_in_env[@]}" "$switch_to_configuration" "$action" || {
        echoerr "errors(s) occurred while switching to the new configuration"
        exit 1
      }
      echo "Successfully switched to the new configuration"
    fi
  ;;
  dry-build)
    echo "Evaluating NixOS configuration: '$configuration'..."
    _nix build --dry-run "$flake_config_attr.config.system.build.toplevel" || exit 1
    echo "Successfully evaluated the configuration"
  ;;
  repl)
    echo "Entering repl with NixOS configuration: '$configuration'..."
    _nix repl \
      --override-flake flake "$flake" \
      --expr "$nix_repl_attrset"
  ;;
  eval)
    if [ -n "$expr" ]; then
      args=(
        --override-flake flake "$flake"
        --impure
        --expr "with $nix_repl_attrset; $evalAttr" .
      )
    else
      args=( "$flake#$evalAttr" )
    fi
    test -n "$raw" && args+=( --raw )
    test -n "$json" && args+=( --json )
    NIX_EXEC=1 _nix eval "${args[@]}"
  ;;
  run)
    if [ -n "$expr" ]; then
      args=(
        --override-flake flake "$flake"
        --impure
        --expr "with $nix_repl_attrset; $runAttr" .
      )
    else
      args=( "$flake#$runAttr" )
    fi
    NIX_EXEC=1 _nix run "${args[@]}" -- "${runArgs[@]}"
  ;;
esac
