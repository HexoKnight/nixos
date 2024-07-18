#!/usr/bin/env bash

SOPS_AGE_KEY_PATH=$HOME/.config/sops/age/keys.txt
DEFAULT_SSH_KEY_PATH=$HOME/.ssh/id_ed25519
name=$(basename "$0")

if [ "${1-}" = "--help" ]; then
  cat << EOF
Usage: $name OPTION [ARG]
Generates a secrets.json file, outputing on stdout.
Options allow methods of getting ahold of / generating anew the required age key
that must be located in '$SOPS_AGE_KEY_PATH'

Options:
  --age <public age key>
    specify a public age key if you have multiple age keys in '$SOPS_AGE_KEY_PATH'
  --age-new
    generate a fresh age key
  --ssh [ssh key path]
    generate an age key from an ssh key (defaults to '$DEFAULT_SSH_KEY_PATH')
  --ssh-pass [ssh key path]
    generate an age key from an ssh key with a passphrase (defaults to '$DEFAULT_SSH_KEY_PATH')
  --help
    show this help and exit
EOF
  exit 1
fi

age_recipient=
sshpass=
if [ "${1-}" = "--ssh" ] || { test "${1-}" = "--ssh-pass" && sshpass=1; }; then
  if [ -e "$SOPS_AGE_KEY_PATH" ]; then
    >&2 echo "file already exists at '$SOPS_AGE_KEY_PATH'"
    exit 1
  fi

  ssh_key_path=${2:-$DEFAULT_SSH_KEY_PATH}
  age_recipient=$(ssh-to-age -i "$ssh_key_path.pub") || {
    >&2 echo "could not find public ssh key at '$ssh_key_path.pub'"
    exit 1
  }
  
  if [ -n "$sshpass" ]; then
    read -rsp "SSH password: " sshpass
    echo
  fi
  SSH_TO_AGE_PASSPHRASE=$sshpass ssh-to-age -private-key -i "$ssh_key_path" -o "$SOPS_AGE_KEY_PATH" || {
    >&2 echo "failed to generate '$SOPS_AGE_KEY_PATH'"
    if [ -z "$sshpass" ]; then
      >&2 echo "if your ssh key is password protected, you can use the --ssh-pass option instead"
      >&2 echo "Try '$name --help'"
    fi
    exit 1
  }
  chmod 600 "$SOPS_AGE_KEY_PATH"

  echo "Successfully created '$SOPS_AGE_KEY_PATH' from ssh key at '$ssh_key_path'"
elif [ "${1-}" = "--age" ]; then
  if [ -z "${2-}" ]; then
    >&2 echo "must specify public age key as second argument"
    exit 1
  fi
  age_recipient=$2
else
  if [ "${1-}" = "--age-new" ]; then
    # I would like to extract both public and private key from
    # just this command but it doesn't look like the public key
    # is meant to be machine read (it goes to stderr) so I
    # wouldn't trust doing so
    age-keygen -o "$SOPS_AGE_KEY_PATH" || {
      >&2 echo "failed to generate fresh age key"
      exit 1
    }
  fi

  age_recipient=$(age-keygen -y "$SOPS_AGE_KEY_PATH") || {
    >&2 echo "failed to generate public age key from '$SOPS_AGE_KEY_PATH'"
    >&2 echo "Try '$name --help'"
    exit 1
  }
fi

echo "Enter new user password:"
hashedPassword=$(mkpasswd)
# TODO: maybe add confirmation
# (ie. enter password again to check)

sops --encrypt \
  --input-type json --output-type json \
  --age "$age_recipient" \
  <(jq \
    --null-input  \
    --arg hashedPassword "$hashedPassword" \
    '$ARGS.named'
  ) || {
  >&2 echo "failed to encrypt secrets"
  >&2 echo "Try '$name --help'"
  exit 1
}
