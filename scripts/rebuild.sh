#!/usr/bin/env bash

# originally from (but now largely altered beyond recognition):
# https://gist.github.com/0atman/1a5133b842f929ba4c1e195ee67599d5

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
rebuild the current system using nixos-rebuild
@option t,type=TYPE Specify the type of rebuild (defaults to switch)
@option d,directory=DIR Specify the directory in which to perform the build
(defaults to \$NIXOS_BUILD_DIR if set or /etc/nixos)
@option c,configuration=CONFIG Specify the configuration to load into
(defaults to \$NIXOS_BUILD_CONFIGURATION if set or the system hostname)
@option u,update=FLAKE Update FLAKE (or all flakes if FLAKE=all) before building
@option ,diff=?WHEN Specify when to display a diff: auto, never, always.
(defaults to auto without this flag, defaults to always when just --diff is given)
@option ,no-diff Alias of --diff=never
@option ,timeout=TIME Timeout password reading after TIMEOUT seconds
@option =EXTRAARGS... extra args to be passed to nixos-rebuild
EOF

rebuild_type=switch
build_dir=${NIXOS_BUILD_DIR-/etc/nixos}
configuration=${NIXOS_BUILD_CONFIGURATION-}
update_flakes=()
diff=auto
timeout=""

while readoption option arg; do
  # readoption sets $arg
  # shellcheck disable=SC2154,SC2269
  arg=$arg
  case "$option" in
    (-t | --type) rebuild_type=$arg ;;
    (-d | --directory) build_dir=$arg ;;
    (-c | --configuration) configuration=$arg ;;
    (-u | --update) update_flakes+=("$arg") ;;

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

    (--timeout) timeout=$arg ;;

    (*) exit 1 ;;
  esac
done
# to satisfy shellcheck
nixos_rebuild_args=()
readremainingpositionalargs nixos_rebuild_args

# cd into directory
pushd "$build_dir" >/dev/null || {
  echoerr "could not enter build dir ('$build_dir')"
  exit 1
}

show_diff=1
case "$diff-$rebuild_type" in never-*|auto-dry-*)
  show_diff=""
esac

if [ ! -v SSH_AUTH_SOCK ]; then
  echoerr 'ssh-agent not running cannot continue'
  exit 1
fi

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

if ! ssh-add -L; then
  read_password
  EVALVAR="cat "<(get_password) SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=evalvar ssh-add || {
    echoerr "ssh password doesn't match sudo password..."
    ssh-add
  }
fi

nix_options=(--option warn-dirty false)

if [ "${#update_flakes[@]}" -gt 0 ]; then
  echo "Updating Flakes..."
  case "${update_flakes[*]}" in "all")
    update_flakes=()
  esac
  nix "${nix_options[@]}" flake update "${update_flakes[@]}" || exit 1
fi

if [ -n "$show_diff" ]; then
  diff -r /etc/nixos-current-system-source ./ --exclude=".git" --color || true
fi

# test for a git repo
if git rev-parse --git-dir >/dev/null 2>&1; then
  # track all non-ignored files (-A) to ensure new (as yet uncommited) files
  # are correctly copied to the store but don't actually stage them (-N)
  git add -AN || {
    >&2 echo "failed to run 'git add -AN' but continuing..."
  }
fi

echo "NixOS Rebuilding..."

# TODO: very probably write custom nixos-rebuild for only local development (eg. no buildHost/targetHost)
sudo --preserve-env=SSH_AUTH_SOCK -- nixos-rebuild "${nix_options[@]}" "$rebuild_type" --flake ".#$configuration" "${nixos_rebuild_args[@]}" || exit 1
  #\
  #|& tee nixos-rebuild.log 2>/dev/null ||
  #(cat nixos-rebuild.log | grep -- color error && false)

if [ "$rebuild_type" != "test" ] && \
   [ "$rebuild_type" != "dry-activate" ] && \
   [ "$rebuild_type" != "dry-build" ]; then
  # Get current generation metadata
  current=$(nixos-rebuild list-generations --flake . | grep current)
  echo "$current"
fi

# Back to prev dir
popd >/dev/null || {
  echoerr "could not return to prev dir (???)"
  exit 1
}

# Notify all OK!
echo "all built successfully :)"
# notify-send -e "NixoOS Rebuilt OK!" --icon=software-update-available
