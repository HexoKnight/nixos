lib:

let
  importFiles = dir:
    builtins.mapAttrs (filename: _:
      import (lib.path.append dir "./${filename}")
    );
in
rec {
  importDir = dir: (importFiles dir) (builtins.readDir dir);

  filterImportDir = f: dir: lib.pipe dir [
    builtins.readDir
    (lib.filterAttrs f)
    (importFiles dir)
  ];

  mapImportNixDirWithoutDefault = f: dir: lib.pipe dir [
    builtins.readDir
    (lib.filterAttrs (filename: filetype:
      filename != "default.nix" && (filetype == "regular" || filetype == "directory")
    ))
    (importFiles dir)
    (lib.mapAttrs' (filename: value:
      let name = lib.removeSuffix ".nix" filename; in
      lib.nameValuePair name (f name value)
    ))
  ];
}
