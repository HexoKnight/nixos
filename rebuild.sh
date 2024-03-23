#!/usr/bin/env bash

# originally from (but now largely altered beyond recognition):
# https://gist.github.com/0atman/1a5133b842f929ba4c1e195ee67599d5

# exit on any command returning a non-zero status
set -e

ARGS=$(getopt --options "t:d:c:u:" --longoptions "type:,directory:configuration:update:" -- "${@}") || exit
eval "set -- ${ARGS}"

while true; do
  case "$1" in
    (-t | --type)
      rebuild_type="$2"
      shift 2
    ;;
    (-d | --directory)
      build_dir="$2"
      shift 2
    ;;
    (-c | --configuration)
      configuration="$2"
      shift 2
    ;;
    (-u | --update)
      update_flakes+=" $2"
      shift 2
    ;;
    (--)
      shift
      break
    ;;
    (*)
      exit 1 # error
    ;;
  esac
done
extra_args="$*"

rebuild_type="${rebuild_type-switch}"
build_dir="${build_dir-"${NIXOS_BUILD_DIR-'/etc/nixos'}"}"
configuration="${configuration-"$NIXOS_BUILD_CONFIGURATION"}"

# cd into directory
pushd "$build_dir" >/dev/null

# Edit config but I won't do that bc flake is a tad more complicated
# ./configuration.nix

# Autoformat nix files
# alejandra . >/dev/null

# show changes
# git diff -U0 *.nix

if [ ! -v SSH_AUTH_SOCK ]; then
  echo ssh-agent not running cannot continue
  exit 1
fi

read_password () {
  if [ ! -v passkey ]; then
    read -s -p "Password: " passkey
    echo
  fi
}

if [ ! -f agekey ]; then
  echo 'age key not found, generating from ssh...'
  read_password
  SSH_TO_AGE_PASSPHRASE="$passkey" nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 -o agekey
fi

if ! ssh-add -L; then
  read_password
  EVALVAR=$(cat <<-EOF
  case \$* in
    Bad*)
      >&2 echo Bad password
      exit 1
    ;;
  esac
  echo $passkey
EOF
  ) SSH_ASKPASS_REQUIRE="force" SSH_ASKPASS="evalvar" ssh-add
fi

if ! sudo -vn &>/dev/null; then
  read_password
  export EVALVAR="echo $passkey"
  export SUDO_ASKPASS="$(which evalvar)"
  sudoarg="-A SSH_AUTH_SOCK=\"$SSH_AUTH_SOCK\""
  sudosshoptions="-I \"ssh-auth-sock=$SSH_AUTH_SOCK\" -I \"ssh-config-file=$HOME/.ssh/config\""
fi

if [ -v update_flakes ]; then
  echo "Updating Flakes..."
  if [ "$update_flakes" == " all" ]; then
    sudo $sudoarg SSH_AUTH_SOCK="$SSH_AUTH_SOCK" nix flake update -I "ssh-auth-sock=$SSH_AUTH_SOCK" -I "ssh-config-file=$HOME/.ssh/config"
  else
    sudo $sudoarg SSH_AUTH_SOCK="$SSH_AUTH_SOCK" nix flake update $update_flakes -I "ssh-auth-sock=$SSH_AUTH_SOCK" -I "ssh-config-file=$HOME/.ssh/config"
  fi
fi

# track all non-ignored files to ensure new files are picked up by nixos-rebuild
git add .

echo "NixOS Rebuilding..."

# Rebuild, output simplified errors, log tracebacks
sudo $sudoarg nixos-rebuild $rebuild_type \
  --flake ".#$configuration" $sudosshoptions \
  -I "ssh-auth-sock=$SSH_AUTH_SOCK" \
  -I "ssh-config-file=$HOME/.ssh/config"
  #\
  #|& tee nixos-rebuild.log 2>/dev/null ||
  #(cat nixos-rebuild.log | grep -- color error && false)

if [ "$rebuild_type" != "test" ] && \
   [ "$rebuild_type" != "dry-activate" ] && \
   [ "$rebuild_type" != "dry-build" ]; then
  echo "Committing to git..."

  # Get current generation metadata
  current=$(nixos-rebuild list-generations --flake . | grep current)

  # Commit all changes with the generation metadata
  echo "$current"
  # git commit -am "$current"
fi

# Back to prev dir
popd >/dev/null

# Notify all OK!
echo "all built successfully :)"
# notify-send -e "NixoOS Rebuilt OK!" --icon=software-update-available
