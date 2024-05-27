{ lib, system, pkgs }:

let
  overrides = {
    where-is-my-sddm-theme-qt5.pkgs = pkgs.libsForQt5;
  };
in

lib.concatMapAttrs (filename: filetype:
  if filename == "default.nix" then {}
  else if filetype == "regular" || filetype == "directory" then
    let
      name = lib.removeSuffix ".nix" filename;
      overridePkgs = overrides.${name}.pkgs or pkgs;
      overrideArgs = overrides.${name}.inputs or {};

      package = overridePkgs.callPackage ./${filename} overrideArgs;
      platforms = package.meta.platforms or lib.platforms.all;
    in
    lib.optionalAttrs (lib.elem system platforms) {
      ${name} = package;
    }
  else {}
) (builtins.readDir ./.)
