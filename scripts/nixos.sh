#!/usr/bin/env bash

# TODO:
# add list-generations support
# add --no-sudo option

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

parse_args "$@" << EOF
@description
Manage a nixos installation.

SUBCOMMANDS
  build - build a nixos configuration
  eval - evaluate a nixos configuration but don't build it
  repl - open a nixos configuration in 'nix repl'
\
@option =SUBCOMMAND #

### SUBCOMMAND OPTIONS

# build
@option b,boot Install boot menu generation
@option s,switch Switch to the new configuration

### NIXOS CONFIGURATION OPTIONS

@option f,flake=FLAKE Specify flake uri(s),
multiple can be delimited by newlines and the first valid one is used
(defaults to \$NIXOS_BUILD_FLAKE if set or /etc/nixos)

@option n,name=NAME Specify configuration name
(defaults to \$NIXOS_BUILD_CONFIGURATION if set or the system hostname)

### OTHER OPTIONS

@option p,profile=NAME Specify name of profile to be used.
Uses '/nix/var/nix/profiles/system' when NAME == 'system', otherwise
uses '/nix/var/nix/profiles/system-profiles/NAME'
(defaults to 'system')

@option ,install-bootloader (re)install the bootloader as specified by the configuration

@option ,link=?WHEN Specify when to produce result symlinks: auto, never, always.
(defaults to auto without this flag, defaults to always when just --link is given)
@option ,no-link Alias of --link=never
@option o,out-link=PATH Specify prefix for result symlinks (defaults to 'result')

@option ,diff=?WHEN Specify when to display a diff: auto, never, always.
(defaults to auto without this flag, defaults to always when just --diff is given)
@option ,no-diff Alias of --diff=never

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
profile=system

install_bootloader=

link=auto
out_link=result
diff=auto

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

  case "$option" in
    (-b | --boot) boot=1 ;;
    (-s | --switch) switch=1 ;;

    (-f | --flake) argrequired; flakes=$arg ;;
    (-n | --name) configuration=$arg ;;
    (-p | --profile) argrequired; profile=$arg ;;

    (--install-bootloader) install_bootloader=1 ;;

    (--link)
      case "$arg" in
        (auto|never|always|"") link=${arg:-always} ;;
        (*)
          echoerr "invalid value '$arg' for $option"
          tryhelpexit
        ;;
      esac
    ;;
    (--no-link) link=never ;;
    (-o | --out-link) out_link=$arg ;;

    (--diff)
      case "$arg" in
        (auto|never|always|"") diff=${arg:-always} ;;
        (*)
          echoerr "invalid value '$arg' for $option"
          tryhelpexit
        ;;
      esac
    ;;
    (--no-diff) diff=never ;;

    (--git-add) git_add=1 ;;

    (-u | --update) update_flakes+=("$arg") ;;

    (--timeout) timeout=$arg ;;

    (*) exit 1 ;;
  esac
done

readexactpositionalargs SUBCOMMAND

######### VALIDATE SUBCOMMANDS/FLAGS ##########

case "$SUBCOMMAND" in
  build|eval|repl) ;;
  *)
    echoerr "'$SUBCOMMAND' is not a valid command"
    tryhelpexit
  ;;
esac

if [ "$SUBCOMMAND" != "build" ]; then
  test -n "$switch" && echoerr "'-s/--switch' only valid for 'build' subcommand"
  test -n "$boot" && echoerr "'-b/--boot' only valid for 'build' subcommand"
  test -n "$install_bootloader" && echoerr "'--install-bootloader' only valid for 'build' subcommand"
fi

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

nix_options=(--option warn-dirty false)

NIX_EXEC=
_nix() {
  if [ -n "$NIX_EXEC" ]; then
    exec nix "${nix_options[@]}" "$@"
  else
    nix "${nix_options[@]}" "$@"
  fi
}

read_password() {
  while [ ! -v passkey ]; do
    if read ${timeout:+-t "$timeout"} -rsp "Password: " passkey; then
      >&2 echo
      sudo -k
      if ! echo "$passkey" | sudo -Sv 2>/dev/null; then
        >&2 echo 'Password incorrect, try again'
        unset passkey
      fi
    else
      >&2 echo
      echoerr "timed out after '$timeout' seconds"
      exit 1
    fi
  done
}
get_password() {
  printf %s "${passkey-}"
}

### ENSURE SSH ACCESS
if [ ! -v SSH_AUTH_SOCK ]; then
  echoerr 'ssh-agent not running cannot continue'
  exit 1
fi

if ! ssh-add -L; then
  read_password
  EVALVAR="cat "<(get_password) SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=evalvar ssh-add || {
    echoerr "ssh password doesn't match sudo password..."
    ssh-add
  }
fi

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
    flake_store_path=$(get_flake_store_path) && break
  elif [ -z "$rest_of_flakes" ]; then
    echoerr "no flakes could be fetched"
    exit 1
  fi
done

echo "Using nixos from flake at '$flake'"

config_attr=nixosConfigurations.\"$configuration\"
flake_config_attr=$flake#$config_attr

######### SETUP ##########

if ! sudo -vn &>/dev/null; then
  echo 'sudo password required...'
  read_password
fi

if [ ! -f ~/.config/sops/agekey ]; then
  echo 'age key not found, generating from ssh...'
  mkdir -p ~/.config/sops/
  read_password
  SSH_TO_AGE_PASSPHRASE=$(get_password) ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/agekey
fi

if [ -z "$IN_NIXOS_BUILD_REEXEC" ] && [ -n "$git_add" ]; then
  # test for a git repo
  if git rev-parse --git-dir >/dev/null 2>&1; then
    flake_metadata=$(get_flake_metadata) || exit 1
    flake_src_dir=$(printf %s "$flake_metadata" | jq -r '
      .resolved |
      if .type == "git" and not has("ref") and not has("rev") then
        .url
      else
        ""
      end
    ')
    if [ -n "$flake_src_dir" ]; then
      flake_src_dir=${flake_src_dir#file://}
      flake_src_dir=${flake_src_dir#file:}

      # track all non-ignored files (-A) to ensure new (as yet uncommited) files
      # are correctly copied to the store but don't actually stage them (-N)
      ( cd "$flake_src_dir" && git add -AN ) || {
        echoerr "failed to run 'git add -AN' but continuing..."
      }
    fi
  else
    echoerr "flake isn't a git repo, ignoring '--git-add'..."
  fi
fi

if [ -z "$IN_NIXOS_BUILD_REEXEC" ] && [ "${#update_flakes[@]}" -gt 0 ]; then
  echo "Updating Flakes..."
  case "${update_flakes[*]}" in "all")
    update_flakes=()
  esac
  _nix flake update "${update_flakes[@]}" || exit 1
fi

if [ -z "$IN_NIXOS_BUILD_REEXEC" ] && [ -n "$show_diff" ]; then
  # refetch flake even if git add already did so (just in case??)...
  flake_store_path=$(get_flake_store_path) || exit 1
  diff -r /etc/nixos-current-system-source "$flake_store_path" --exclude=".git" --color || true
fi

######### BUILDING ##########

# re-exec nixos if the configuration is going to be 'used'
# after being built to, for example, prevent getting stuck
# (if only temporarily) in a system with a broken nixos command
if [ -z "$IN_NIXOS_BUILD_REEXEC" ] && [ -n "$boot$switch" ]; then
  IN_NIXOS_BUILD_REEXEC=1 NIX_EXEC=1 _nix run "$flake_config_attr.pkgs.local.nixos" -- "$@"
fi

tmpDir=$(mktemp -d rebuild-XXXXXX) || {
  echoerr "mktemp failed, cannot continue"
  exit 1
}
cleanup() {
  rm -rf "$tmpDir"
}
trap cleanup EXIT

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
      sudo mkdir -p -m 0755 "$(dirname "$profile_path")" || exit 1
      # TODO: figure out how to do the same with 'nix profile'
      sudo nix-env -p "$profile_path" --set "$configuration_path" || exit 1
      echo "Successfully made the new configuration the boot default"
    fi

    if [ -n "$boot$switch" ]; then
      # for future specialisation support
      switch_to_configuration=$configuration_path/bin/switch-to-configuration

      # see nixos-rebuild source
      run_in_env=(
        sudo
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
          sudo
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
  eval)
    echo "Evaluating NixOS configuration: '$configuration'..."
    _nix build --dry-run "$flake_config_attr.config.system.build.toplevel" || exit 1
  ;;
  repl)
    echo "Entering repl with NixOS configuration: '$configuration'..."
    _nix repl \
      --override-flake flake "$flake" \
      --expr '
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
  ;;
esac
