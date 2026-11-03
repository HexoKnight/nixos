#!/usr/bin/env bash

LINK_DIR=$(readlink -f "${1?library link path should be first arg}")
ORIG_DIR=$(readlink -f "${2?library original path should be second arg}")

fd --base-directory "$ORIG_DIR" --type file --ignore-file <(
    fd --base-directory "$LINK_DIR" --type symlink --exec-batch readlink |
    while read -r path; do
        printf '%q\n' "${path##"$ORIG_DIR"}"
    done
) |
while read -r path; do
    echo "linking: $path"
    mkdir --parents "$(dirname "$LINK_DIR/$path")"
    ln --symbolic --force --no-target-directory "$ORIG_DIR/$path" "$LINK_DIR/$path"
done
