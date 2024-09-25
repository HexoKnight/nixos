#!/usr/bin/env bash

if [ -n "${1-}" ]; then
  flake=$1
  shift 1
else
  >&2 echo "pass flake as first argument in form 'flake-uri#config-name'"
  exit 1
fi

mount_point=/mnt
if [ -n "${1-}" ]; then
  mount_point=$1
  shift 1
fi

findmnt "$mount_point" && umount -R "$mount_point"
echo "running disko..."
disko --root-mountpoint "$mount_point" --flake "$flake" --mode format
disko --root-mountpoint "$mount_point" --flake "$flake" --mode mount

echo "Installing NixOS configuration: '$flake'..."
nixos-install --root "$mount_point" --flake "$flake" --no-root-password --no-channel-copy
