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
@option =TARGET #
@description
link the appropriate file/dir in /persist/(system|home) to TARGET
(using mklink internally)
EOF

while readoption option _arg; do
  case "$option" in
    (*) exit 1 ;;
  esac
done

readexactpositionalargs TARGET

fullpath=$(realpath "$TARGET")

case "$fullpath" in
  /home/*) mklink "/persist$fullpath"        "$fullpath" ;;
   *) sudo mklink "/persist/system$fullpath" "$fullpath" ;;
esac
