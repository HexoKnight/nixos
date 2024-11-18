{ lib, pkgs, config, ... }:

let
  fzfBin = lib.getExe config.programs.fzf.package;

  genCommandLineArgs = args: toString ([
    (lib.cli.toGNUCommandLineShell {} (builtins.removeAttrs args [ "--" ]))
  ] ++ lib.optionals (args ? "--") [
    "--"
    (lib.escapeShellArgs (lib.toList args."--"))
  ]);

  genFzfCommand = {
    defaultCommand ? null,
    withData ? false,
    binds ? {},
    options ? {},
    extraArgs ? []
  }:
  let
    setDefaultCommand = if defaultCommand == null then "" else lib.toShellVar "FZF_DEFAULT_COMMAND" defaultCommand;

    jqBin = lib.getExe pkgs.jq;
    spongeBin = lib.getExe' pkgs.moreutils "sponge";
    fzfDataBinPath = lib.makeBinPath [
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
      bind = genFzfbinds binds ++ lib.toList options.bind or [];
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
      "${type}-fzf-data ${lib.escapeShellArg jqFilter} ${genCommandLineArgs args}";
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
      delimiterList = map lib.stringToCharacters [
        "()" "[]" "{}" "<>"
        "~" "!" "@" "#" "$" "%" "^" "&" "*" ";" "/" "|"
      ];

      actionList = lib.concatMap (action:
        let
          actionName = action.name or action;
          actionArgs = lib.toList (action.arg or null);
        in
        map (actionArg:
          let
            delimiterPair = lib.findFirst
              (pair: builtins.match ".*${lib.escapeRegex (lib.last pair)}[+,].*" actionArg == null)
              (throw "no valid delimiters for fzf bind action arg: '${actionArg}'")
              delimiterList;

            startDelimiter = lib.head delimiterPair;
            endDelimiter = lib.last delimiterPair;
          in
          if actionArg == null
          then actionName
          else lib.concatStrings [ actionName startDelimiter actionArg endDelimiter ]
        ) actionArgs
      ) (if builtins.isAttrs actions && !actions ? name then lib.mapAttrsToList withArg actions else lib.toList actions);
      actionString = builtins.concatStringsSep "+" actionList;
    in
    "${key}:${actionString}"
  );
in
{
  config = {
    lib.fzf = {
      inherit genFzfCommand genFzfbinds fzf-data;
    };
  };
}
