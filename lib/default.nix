lib:

let
  callLibs = file: import file lib;
in {
  scripts = callLibs ./scripts.nix;
}
