{ lib, config, ... }:

let
  charFlags = charTest:
    let
      isCharAllowed =
        if lib.isFunction charTest then charTest
        else if lib.isString charTest then lib.flip lib.elem (lib.stringToCharacters charTest)
        else abort "`charTest` must be a function or a string";
      isValid = str:
        let
          chars = lib.stringToCharacters str;
        in
        lib.allUnique chars && lib.all isCharAllowed chars;
    in
    lib.mkOptionType {
      name = "charFlags";
      description = "character flags";
      descriptionClass = "noun";
      check = x: lib.types.str.check x && isValid x;
      merge = loc: defs: lib.hyprbinds.mergeFlags (lib.getValues defs);
    };
in {
  options.hyprbinds = lib.mkOption {
    description = "list of hyprland bindings";
    default = {};
    type = let inherit (lib) types; in
    let
      bindActionSubmodule = types.submodule ({ name, config, ... }: {
        options = {
          flags = lib.mkOption {
            description = "flags applied to bind (eg. \"rm\" => \"bindrm = ...\")";
            default = "";
            type = charFlags "lrenmti";
          };
          dispatcher = lib.mkOption {
            description = "dispatcher to be invoked";
            type = types.strMatching "[^,]+";
          };
          args = lib.mkOption {
            description = "args to be passed to the dispatcher";
            default = "";
            type = types.str;
          };
          __full = lib.mkOption {
            internal = true;
            visible = false;
            type = types.str;
            default = if lib.elem "m" (lib.stringToCharacters config.flags)
              then
                assert (config.args == "" || throw "mouse bind ('m' flag) cannot have args");
                config.dispatcher
              else "${config.dispatcher}, ${config.args}";
          };
        };
      });
      bindAction = (types.coercedTo types.str (s: { __full = s; }) bindActionSubmodule);
      bindMultiAction = types.either bindAction (types.listOf bindAction);
    in
    types.attrsOf bindMultiAction;
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
      binds = lib.concatLists (lib.mapAttrsToList (keybind: actions: map (toBindArg keybind) (lib.toList actions)) hyprbinds);
      groupedBinds = lib.groupBy (bind: bind.flags) binds;
      bindAttrset = lib.mapAttrs' (flags: binds: lib.nameValuePair "bind${flags}" (map (bind: bind.arg) binds)) groupedBinds;
    in
    bindAttrset;
  };
}
