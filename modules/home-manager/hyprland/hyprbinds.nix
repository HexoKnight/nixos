{ config, lib, ... }:

with lib;
let
  charFlags = charTest:
    let
      isCharAllowed =
        if isFunction charTest then charTest
        else if isString charTest then flip elem (stringToCharacters charTest)
        else abort "`charTest` must be a function or a string";
      isValid = str:
        let
          chars = stringToCharacters str;
        in
        allUnique chars && all isCharAllowed chars;
    in
    mkOptionType {
      name = "charFlags";
      description = "character flags";
      descriptionClass = "noun";
      check = x: types.str.check x && isValid x;
      merge = loc: defs: concatStrings (unique (concatMap (x: stringToCharacters x.value) defs));
    };
in {
  options.hyprbinds = mkOption {
    description = "list of hyprland bindings";
    default = {};
    type = with types;
    let
      bindActionSubmodule = submodule ({ name, config, ... }: {
        options = {
          flags = mkOption {
            description = "flags applied to bind (eg. \"rm\" => \"bindrm = ...\")";
            default = "";
            type = charFlags "lrenmti";
          };
          dispatcher = mkOption {
            description = "dispatcher to be invoked";
            type = strMatching "[^,]+";
          };
          args = mkOption {
            description = "args to be passed to the dispatcher";
            default = "";
            type = str;
          };
          __full = mkOption {
            internal = true;
            visible = false;
            type = str;
            default = "${config.dispatcher}, ${config.args}";
          };
        };
        config = {
          # wayland.windowManager.hyprland.settings."bind${config.flags}" =
          #   "${name}, ${config.__full}";
        };
      });
      bindAction = (coercedTo str (s: { __full = s; }) bindActionSubmodule);
      bindMultiAction = either bindAction (listOf bindAction);
    in
    attrsOf bindMultiAction;
  };

  config = {
    wayland.windowManager.hyprland.settings =
    let
      hyprbinds = config.hyprbinds;
      toBindArg = keybind: bindAction: {
        inherit (bindAction) flags;
        arg =
          assert ((builtins.match "[^,]*,[^,]+" keybind) != null || throw "keybind (${keybind}) must contain exactly one comma seperator");
          "${keybind}, ${bindAction.__full}";
      };
      binds = concatLists (mapAttrsToList (keybind: actions: map (toBindArg keybind) (toList actions)) hyprbinds);
      groupedBinds = groupBy (bind: bind.flags) binds;
      bindAttrset = mapAttrs' (flags: binds: nameValuePair "bind${flags}" (map (bind: bind.arg) binds)) groupedBinds;
    in
    bindAttrset;
  };
}
