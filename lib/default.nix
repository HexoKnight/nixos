lib:

let
  callLibs = file: import file lib;
in {
  scripts = callLibs ./scripts.nix;
  hyprbinds = callLibs ./hyprbinds.nix;
  dir = callLibs ./dir.nix;
}
