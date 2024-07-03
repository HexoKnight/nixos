#!/usr/bin/env bash

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
@option q,quiet suppress less important output
@option =REALDIR #
@option =LINKFILE #
@description
Create a symbolic link at LINKFILE pointing to REALDIR:
if LINKFILE is an empty dir or missing:
    simply create a symlink as normal
else if REALDIR is an empty dir or missing:
    move LINKFILE to REALDIR and symlink as normal
else if environment variable MKLINK_NO_BACKUP is unset/empty:
    backup REALDIR, move LINKFILE to REALDIR and symlink as normal
else:
    fail with a non-zero exit code
EOF

while readoption option _arg; do
  case "$option" in
    (-q|--quiet) quiet=true ;;
    (*) exit 1 ;;
  esac
done

readexactpositionalargs REALDIR LINKFILE

real_dir=$(realpath -s "$REALDIR")
link_dir=$(realpath -s "$LINKFILE")

ifnotquiet() {
  test -z "$quiet" && "$@"
}

if [ "$(readlink "$link_dir")" = "$real_dir" ]; then
  ifnotquiet echo "'$link_dir' already correctly linked to '$real_dir'"
  exit 0
fi

# check if no file exists then make parent directories
# or if it is an empty directory then delete it
ensureAvailable() {
  {
    test ! -e "$1" &&
    mkdir -p "$(dirname "$1")"
  } || {
    test -n "$(find "$1" -maxdepth 0 -empty)" &&
    rmdir "$1"
  }
}

if ensureAvailable "$link_dir"; then
  ifnotquiet echo "'$link_dir' empty..."
  mkdir -p "$real_dir"
elif ensureAvailable "$real_dir"; then
  ifnotquiet echo "'$link_dir' not empty but '$real_dir' is so moving the former to the latter..."
  mv -T "$link_dir" "$real_dir"
else
  # even if quiet
  echo "files present in both linked dir ('$link_dir') and real dir ('$real_dir')"

  if [ -z "$MKLINK_NO_BACKUP" ]; then
    echo "backing up the real dir and using files from the linked dir"
    mv --backup=numbered -T "$link_dir" "$real_dir"
  else
    echo "backing up disabled, so failing"
    exit 1
  fi
fi
ln -s -T "$real_dir" "$link_dir" &&
ifnotquiet echo "successfully linked '$link_dir' to '$real_dir'"
