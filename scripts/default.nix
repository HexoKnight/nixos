{ lib, pkgs }:

rec {
  configopts = pkgs.writeTextFile {
    name = "configopts";
    destination = "/bin/configopts.sh";
    text = ''
      #!/usr/bin/env sh

      getopt() {
        ${lib.getExe' pkgs.util-linux "getopt"} "$@"
      }

      ${builtins.readFile ./configopts.sh}
    '';
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
    runtimeInputs = [ mklink configopts ];
    extraShellCheckFlags = [ "-x" "-P" (lib.makeBinPath [ configopts ]) ];
    text = builtins.readFile ./persist.sh;
  };

  evalvar = pkgs.writeShellScriptBin "evalvar" ''eval "$EVALVAR"'';
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = [ configopts pkgs.ssh-to-age evalvar pkgs.nixVersions.nix_2_19 ];
    extraShellCheckFlags = [ "-x" "-P" (lib.makeBinPath [ configopts ]) ];
    text = builtins.readFile ./rebuild.sh;
  };

  linkSaveDirs = pkgs.writeShellApplication {
    name = "linkSaveDirs";
    text =
    let
      jqBin = lib.getExe pkgs.jq;
      mklinkBin = lib.getExe mklink;
      xargsBin = lib.getExe' pkgs.findutils "xargs";
    in /* bash */ ''
      LINKED_SAVES_DIR=''${LINKED_SAVES_DIR:-$HOME/Saves}
      LINKED_SAVES_LIST=''${LINKED_SAVES_LIST:-$LINKED_SAVES_DIR/list.json}

      if [ ! -f "$LINKED_SAVES_LIST" ]; then
        >&2 echo "linked saves list ('$LINKED_SAVES_LIST') not found"
        exit 1
      fi

      <"$LINKED_SAVES_LIST" ${jqBin} --raw-output0 \
        --arg savesDir "$LINKED_SAVES_DIR" '
        to_entries[] |
        ($ARGS.named.savesDir + "/" + .key, .value)
      ' |
      ${xargsBin} -0 -L2 ${mklinkBin}
    '';
  };
  addLinkedSave = pkgs.writeShellApplication {
    name = "addLinkedSave";
    text =
    let
      jqBin = lib.getExe pkgs.jq;
      mklinkBin = lib.getExe mklink;
      spongeBin = lib.getExe' pkgs.moreutils "sponge";
    in /* bash */ ''
      LINKED_SAVES_DIR=''${LINKED_SAVES_DIR:-$HOME/Saves}
      LINKED_SAVES_LIST=''${LINKED_SAVES_LIST:-$LINKED_SAVES_DIR/list.json}

      if [ -z "$1" ]; then
        >&2 echo 'the save location must be passed as the first parameter'
        exit 1
      fi
      save_dir=$(realpath -s "$1")
      save_name=''${2:-$(basename "$save_dir")}

      test ! -e "$LINKED_SAVES_LIST" && echo '{}' >"$LINKED_SAVES_LIST"

      <"$LINKED_SAVES_LIST" ${jqBin} \
        --arg name "$save_name" \
        --arg dir "$save_dir" \
        '.[$name] = $dir' |
      ${spongeBin} "$LINKED_SAVES_LIST"

      ${mklinkBin} "$LINKED_SAVES_DIR/$save_name" "$save_dir"
    '';
  };
}
