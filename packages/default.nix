{ lib, pkgs }:

let
  overrides = {
  };
in

lib.pipe ./. [
  (lib.dir.mapImportNixDirWithoutDefault (name: pkgExpr:
    let
      overridePkgs = overrides.${name}.pkgs or pkgs;
      overrideArgs = overrides.${name}.inputs or {};

      package = overridePkgs.callPackage pkgExpr overrideArgs;
    in
    package
  ))
  (lib.filterAttrs (name: package:
    lib.elem pkgs.stdenv.hostPlatform.system (package.meta.platforms or lib.platforms.all)
  ))
]
