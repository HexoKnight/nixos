{ lib, pkgs, config, ... }:

with lib;
let
  fzfBin = lib.getExe config.programs.fzf.package;
  fdBin = lib.getExe pkgs.fd;

  fzf-tab-completion = pkgs.fetchFromGitHub {
    owner = "lincheney";
    repo = "fzf-tab-completion";
    rev = "ae8462e19035af84586ac6871809e911d641a50c";
    hash = "sha256-0HAAHJqsX78QGDQ+ltUtM64RL4M1DCWzwc3kNHjoRFM=";
  };

  genCommandLineArgs = args: toString ([
    (cli.toGNUCommandLineShell {} (builtins.removeAttrs args [ "--" ]))
  ] ++ optionals (args ? "--") [
    "--"
    (escapeShellArgs (toList args."--"))
  ]);

  genFzfCommand = {
    defaultCommand ? null,
    withData ? false,
    binds ? {},
    options ? {},
    extraArgs ? []
  }:
  let
    setDefaultCommand = if defaultCommand == null then "" else toShellVar "FZF_DEFAULT_COMMAND" defaultCommand;

    jqBin = getExe pkgs.jq;
    spongeBin = getExe' pkgs.moreutils "sponge";
    fzfDataBinPath = makeBinPath [
      (pkgs.writeShellScriptBin "get-fzf-data" ''
        exec <"$FZF_DATA_FILE" ${jqBin} "$@"
      '')
      (pkgs.writeShellScriptBin "set-fzf-data" ''
        exec >"$FZF_DATA_FILE" ${jqBin} "$@"
      '')
      (pkgs.writeShellScriptBin "edit-fzf-data" ''
        <"$FZF_DATA_FILE" ${jqBin} "$@" | ${spongeBin} "$FZF_DATA_FILE"
      '')
    ];

    commandLineArgs = genCommandLineArgs (options // {
      bind = genFzfbinds binds ++ toList options.bind or [];
    });

    mainCommand = toString [
      setDefaultCommand
      fzfBin
      commandLineArgs
      extraArgs
    ];
  in 
  if withData then /* bash */ ''(
    FZF_DATA_DIR=''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/fzf-data
    mkdir -p "$FZF_DATA_DIR"
    export FZF_DATA_FILE=$(mktemp -p "$FZF_DATA_DIR" "XXXXXXXXXX.json")
    echo '{}' >"$FZF_DATA_FILE"
    export PATH="${fzfDataBinPath}":$PATH
    ${mainCommand}
    rm -rf "$FZF_DATA_FILE"
  )''
  else mainCommand;

  withArg = name: arg: { inherit name arg; };

  fzf-data = 
  let
    fzf-data-command = type: args: jqFilter:
      "${type}-fzf-data ${escapeShellArg jqFilter} ${genCommandLineArgs args}";
  in
  rec {
    get = fzf-data-command "get";
    get-flags = get {r = true;} /* jq */ ''.flags | map_values(. // empty) | keys | @sh'';

    set = fzf-data-command "set";

    edit = fzf-data-command "edit";
    toggle = path:
      edit { args = true; "--" = path; } /* jq */ ''setpath($ARGS.positional; getpath($ARGS.positional) // false | not)'';
    toggle-flag = flag:
      toggle [ "flags" flag ];
    toggle-flag-update-prompt = defaultCommand: flag: /* bash */ ''
      ${toggle-flag flag}
      flags=$(${get-flags})
      flags_unescaped=$(eval "printf '%s ' $flags")
      echo "change-prompt(''${flags_unescaped% }> )+reload:${defaultCommand} $flags"
    '';
  };

  genFzfbinds = lib.mapAttrsToList (key: actions:
    let
      delimiterList = map stringToCharacters [
        "()" "[]" "{}" "<>"
        "~" "!" "@" "#" "$" "%" "^" "&" "*" ";" "/" "|"
      ];

      actionList = concatMap (action:
        let
          actionName = action.name or action;
          actionArgs = toList (action.arg or null);
        in
        map (actionArg:
          let
            delimiterPair = lib.findFirst
              (pair: builtins.match ".*${escapeRegex (last pair)}[+,].*" actionArg == null)
              (throw "no valid delimiters for fzf bind action arg: '${actionArg}'")
              delimiterList;

            startDelimiter = head delimiterPair;
            endDelimiter = last delimiterPair;
          in
          if actionArg == null
          then actionName
          else concatStrings [ actionName startDelimiter actionArg endDelimiter ]
        ) actionArgs
      ) (if builtins.isAttrs actions && !actions ? name then mapAttrsToList withArg actions else toList actions);
      actionString = builtins.concatStringsSep "+" actionList;
    in
    "${key}:${actionString}"
  );
in
{
  lib.fzf = {
    inherit genFzfCommand genFzfbinds fzf-data;
  };

  programs.fzf = {
    enable = true;
    defaultCommand = fdBin;
    defaultOptions = [
      (cli.toGNUCommandLineShell {} {
        bind = genFzfbinds {
          ctrl-y = "preview-up";
          ctrl-e = "preview-down";
          ctrl-b = "preview-page-up";
          ctrl-f = "preview-page-down";
          ctrl-u = "preview-half-page-up";
          ctrl-d = "preview-half-page-down";
          tab = "down";
          shift-tab = "up";
          ctrl-space = "select";
        };
        no-mouse = true;
        reverse = true;
        height = "~10";
      })
    ];
  };

  programs.bash.initExtra =
  let
    fileBin = lib.getExe pkgs.file;
    batBin = lib.getExe pkgs.bat;
    ezaBin = lib.getExe pkgs.eza;
  in /* bash */ ''
    __fzf_select__() {
      ${genFzfCommand rec {
        defaultCommand = "fd -HE '.git'";
        withData = true;
        binds =
        let
          toggle-flag = fzf-data.toggle-flag-update-prompt defaultCommand;
        in
        {
          focus.transform-header = "${fileBin} -Lb {}";
          alt-l.transform = toggle-flag "-L";
          alt-d.transform = toggle-flag "-td";
          alt-f.transform = toggle-flag "-tf";
          alt-x.transform = toggle-flag "-tx";
          alt-e.transform = toggle-flag "-te";
          enter.become = "printf '%q' {}";
        };
        options = {
          preview = "${batBin} -n --color=always {} | head -200";
          scheme = "path";
          multi = true;
        };
      }}
    }
    __fzf_cd__() {
      ${genFzfCommand rec {
        defaultCommand = "fd -td -HE '.git'";
        withData = true;
        binds = {
          alt-l.transform = fzf-data.toggle-flag-update-prompt defaultCommand "-L";
          enter.become = "printf 'cd -- %q' {}";
        };
        options = {
          preview = "${ezaBin} --tree --colour=always {} | head -200";
          scheme = "path";
          no-multi = true;
        };
      }}
    }

    source ${fzf-tab-completion}/bash/fzf-bash-completion.sh
    bind -x '"\t": fzf_bash_completion'
    FZF_COMPLETION_AUTO_COMMON_PREFIX=true
    FZF_COMPLETION_AUTO_COMMON_PREFIX_PART=true
  '';
}
