{ lib, pkgs }:

rec {
  configopts = pkgs.writeTextFile {
    name = "configopts";
    destination = "/bin/configopts.sh";
    text = builtins.readFile ./configopts.sh;
    # mostly straight from writeShellApplication source
    checkPhase =
      # GHC (=> shellcheck) isn't supported on some platforms (such as risc-v)
      # but we still want to use writeShellApplication on those platforms
      let
        inherit (pkgs) stdenv shellcheck-minimal;
        shellcheckSupported = lib.meta.availableOn stdenv.buildPlatform shellcheck-minimal.compiler;
        shellcheckCommand = lib.optionalString shellcheckSupported ''
          # use shellcheck which does not include docs
          # pandoc takes long to build and documentation isn't needed for just running the cli
          ${lib.getExe shellcheck-minimal} "$target"
        '';
      in ''
        runHook preCheck
        ${stdenv.shellDryRun} -o posix "$target"
        ${shellcheckCommand}
        runHook postCheck
      '';
  };

  mklink = pkgs.writeShellApplication {
    name = "mklink";
    runtimeInputs = [ configopts ];
    bashOptions = [];
    extraShellCheckFlags = [ "-x" "-P" (lib.makeBinPath [ configopts ]) ];
    text = builtins.readFile ./mklink.sh;
  };
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
