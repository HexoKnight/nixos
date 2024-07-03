{ lib, pkgs }:

rec {
  persist = pkgs.writeShellApplication {
    name = "persist";
    excludeShellChecks = [ "SC2086" ];
    text = builtins.readFile ./persist.sh;
  };

  evalvar = pkgs.writeShellScriptBin "evalvar" ''eval "$EVALVAR"'';
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = [ evalvar pkgs.nixVersions.nix_2_19 ];
    bashOptions = [];
    excludeShellChecks = [ "SC2034" "SC2155" "SC2086" ];
    text = builtins.readFile ./rebuild.sh;
  };
}
