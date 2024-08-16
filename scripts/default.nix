{ lib, pkgs }:

rec {
  configopts = pkgs.writeTextFile rec {
    name = "configopts";
    meta.mainProgram = "configopts.sh";
    destination = "/bin/${meta.mainProgram}";
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
  # deprecated
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = [ configopts pkgs.ssh-to-age evalvar pkgs.nixVersions.nix_2_19 ];
    extraShellCheckFlags = [ "-x" "-P" (lib.makeBinPath [ configopts ]) ];
    text = builtins.readFile ./rebuild.sh;
  };

  nixos = pkgs.writeShellApplication {
    name = "nixos";
    extraShellCheckFlags = [ "-x" "-P" (lib.makeBinPath [ configopts ]) ];
    text = builtins.readFile ./nixos.sh;

    derivationArgs.preCheck =
    let
      inherit (lib) getExe;
      sedScript = lib.concatLines (lib.mapAttrsToList (name: bin:
        "0,\\|^${name}=.*$|s||${name}=${bin}|"
      ) {
        jq = getExe pkgs.jq;
        sops = getExe pkgs.sops;
        nix = getExe pkgs.nixVersions.nix_2_19;
        configopts = getExe configopts;
      });
    in ''
      sed -iEe ${lib.escapeShellArg sedScript} $target
    '';
  };

  gen-sops-secrets = pkgs.writeShellApplication {
    name = "gen-sops-secrets";
    runtimeInputs = with pkgs; [
      ssh-to-age age sops
      jq
    ];
    text = builtins.readFile ./gen-sops-secrets.sh;
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

  batman = pkgs.writeShellApplication {
    name = "batman";
    text =
    let
      sedBin = lib.getExe pkgs.gnused;
      batBin = lib.getExe pkgs.bat;

      # essentially just removes then reinserts some ANSI colour codes around man page references ('... man-page(7) ...')
      # to avoid bat misinterpreting (part of) them as literal text
      # this then allows default man highlighting to coexist with bat's highlighting :)

      # some bat manpage parsing is reimplemented here... :/
      # really it shouldn't be hard for bat itself to take ansi codes into account when highlighting but eh
    in /* bash */ ''
      # for the NOTANOPTION example
      # shellcheck disable=SC2016
      ${sedBin} -Ee '
        # escape <ANSI>man-page<ANSI>(7) -> xxESCAPESTARTxx<ANSI>xxESCAPEENDxxman-pagexxESCAPESTARTxx<ANSI>xxESCAPEENDxx(7)
        s/((\x1B\[[;0-9]+m)*)([-._A-Za-z0-9]+)((\x1B\[[;0-9]+m)*)(\([0-9]+\))/xxESCAPESTARTxx\1xxESCAPEENDxx\3xxESCAPESTARTxx\4xxESCAPEENDxx\6/g

        # escape word(just stuff in brackets) -> word xxESCAPESPACExx (just stuff in brackets)
        s/([^([:space:]]+)\(/\1 xxESCAPESPACExx (/g
        s/(xxESCAPEENDxx|-|=) xxESCAPESPACExx \(/\1(/g

        # bat thinks that anything starting with a dash and indented with 7 spaces
        # is an option, even "       - $NOTANOPTION"
        s/(^[ ]{7})(-+\s)/\1 xxESCAPESPACExx \2/

        # remove empty escapes
        s/xxESCAPESTARTxxxxESCAPEENDxx//g

        # continue escaping in xx..xx \e[1;2m\e[3;4m -> 1;2-3;4-
        : escape_ansi
        s/(xxESCAPESTARTxx[-;0-9]*)\x1B\[([;0-9]+)m([\x1B[m;0-9]*xxESCAPEENDxx)/\1\2-\3/g
        t escape_ansi

        # continue escaping in xx..xx 1;2-3;4- -> 1-2-3-4-
        : escape_delim
        s/(xxESCAPESTARTxx[-0-9]*);([;0-9]*xxESCAPEENDxx)/\1-\2/g
        t escape_delim
      ' |
      ${batBin} -pp --language=man --color=always |
      ${sedBin} -Ee '
        # unescape word xxESCAPESPACExx (just stuff in brackets) -> word(just stuff in brackets)
        s/ ((\x1B\[[0-9;]+m)*)xxESCAPESPACExx((\x1B\[[0-9;]+m)*) /\1\3/g

        # unescape in xx..xx 1-2-3-4- -> 1;2;3;4;
        : unescape_delim
        s/(xxESCAPESTARTxx[;0-9]*)-([-0-9]*xxESCAPEENDxx)/\1;\2/g
        t unescape_delim

        # unescape xxESCAPESTARTxx1;2;3;4;xxESCAPEENDxx -> \e[1;2;3;4m
        s/xxESCAPESTARTxx([;0-9]+);xxESCAPEENDxx/\x1B[\1m/g

        # \e\e[1m[2;3m -> \e[\e[1m2;3m
        s/\x1B((\x1B\[[0-9;]+m)+)\[/\1\x1B[/g
        # \e[\e[1m2;3m -> \e[2;3\e[1mm
        : move_inner
        s/\x1B\[([0-9;]*)((\x1B\[[0-9;]+m)+)([0-9;]+)/\2\x1B[\1\4/g
        t move_inner
        # \e[2;3\e[1mm -> \e[2;3m\e[1m
        s/\x1B\[([0-9;]+)((\x1B\[[0-9;]+m)+)m/\2\x1B[\1m/g
      ' |
      ${batBin} --style=plain --paging=always "$@"
    '';
  };
}
