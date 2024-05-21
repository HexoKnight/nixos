#!/usr/bin/env bash

set -e

fullpath="$(realpath ${1:?pass the file path as an argument})"

if [[ "$fullpath" =~ ^/home/ ]]; then
  cp --parents -a "$fullpath" /persist
else
  sudo cp --parents -a "$fullpath" /persist/system
fi
