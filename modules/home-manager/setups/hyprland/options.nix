{ lib, config, ... }:

let
  t = lib.types;

  toLuaExpr = lib.generators.toLua { };

  toLuaStmt = v: if v._type or null == "lua-inline" then v.expr else toLuaExpr v;

  luaValueType =
    t.nullOr (
      t.oneOf [
        t.bool
        t.int
        t.float
        t.str
        t.path
        (t.attrsOf luaValueType)
        (t.listOf luaValueType)
        t.luaInline
        (t.coercedTo luaFunctionNix mkLuaFunction t.luaInline)
      ]
    )
    // {
      description = "Lua value";
    };

  luaFunctionNix = t.functionTo (t.either luaValueType luaFunctionNix);
  mkLuaFunction =
    let
      genArgs =
        args: f:
        let
          fArgs = lib.attrNames (lib.functionArgs f);
          arg =
            assert lib.length fArgs == 1;
            lib.mkLuaInline (lib.head fArgs);
        in
        if !lib.isFunction f then
          {
            inherit args;
            body = lib.toList f;
          }
        else if args == [ ] && fArgs == [ ] then
          {
            args = [ ];
            body = lib.toList (f { });
          }
        else
          genArgs (args ++ [ arg ]) (f arg);
    in
    f:
    let
      inherit (genArgs [ ] f) args body;

      inner = if body == [ ] then " " else "\n  ${lib.concatMapStringsSep "\n  " toLuaStmt body}\n";
    in
    lib.mkLuaInline ("function(${lib.concatMapStringsSep ", " toLuaExpr args})${inner}end");

  cfg = config.wayland.windowManager.hyprland;
in
{
  options.wayland.windowManager.hyprland = {
    events = lib.mkOption {
      description = "Attribute set of Hyprland lua events";
      default = { };
      type =
        let
          maybeSingle = t.coercedTo luaValueType lib.singleton (t.listOf luaValueType);
        in
        t.attrsOf maybeSingle;
    };

    binds = lib.mkOption {
      description = "Attribute set of Hyprland lua bindings";
      default = { };
      type =
        let
          inherit (lib) types;

          bindActionSubmodule = types.submodule (
            { name, config, ... }:
            {
              options = {
                dispatcher = lib.mkOption {
                  description = "Lua dispatcher (hl.dsp.*) to be invoked";
                  type = types.strMatching "[^,]+";
                };
                args = lib.mkOption {
                  description = "Dispatcher args";
                  default = [ ];
                  type = types.either luaValueType (types.listOf luaValueType);
                };
                rawLua = lib.mkOption {
                  description = "Raw Lua to be passed as the dispatcher";
                  type = luaValueType;
                  default = lib.mkLuaInline "hl.dsp.${config.dispatcher}(${
                    lib.concatMapStringsSep ", " toLuaExpr (lib.toList config.args)
                  })";
                };
                flags = lib.mkOption {
                  description = "Bind flags";
                  default = [ ];
                  type = types.listOf types.str;
                };
              };
            }
          );
          bindMultiAction = types.either bindActionSubmodule (types.listOf bindActionSubmodule);
        in
        types.attrsOf bindMultiAction;
    };
  };

  config = {
    lib.hypr = {
      binds = rec {
        mkBind = dispatcher: args: {
          inherit dispatcher args;
        };

        mkNoArgBind = dispatcher: {
          inherit dispatcher;
        };

        mkExec = prog: mkBind "exec_cmd" [ prog ];

        mkMouseBind = withFlag "mouse" mkNoArgBind;

        addFlags =
          newFlags:
          {
            flags ? [ ],
            ...
          }@bind:
          bind
          // {
            flags = flags ++ newFlags;
          };

        withFlags =
          flags: bind: if lib.isFunction bind then arg: withFlags flags (bind arg) else addFlags flags bind;
        withFlag = flag: withFlags [ flag ];

        repeating = withFlag "repeating";
      };
    };
    wayland.windowManager.hyprland = {
      settings.on =
        let
          events = lib.mapAttrsToList (
            name:
            lib.map (value: {
              _args = [
                name
                value
              ];
            })
          ) cfg.events;

        in
        lib.flatten events;

      settings.bind =
        let
          binds = lib.concatLists (
            lib.mapAttrsToList (
              key: binds:
              lib.map (bind: {
                _args = [
                  key
                  bind.rawLua
                  (lib.genAttrs bind.flags (_: true))
                ];
              }) (lib.toList binds)
            ) cfg.binds
          );
        in
        lib.flatten binds;
    };
  };
}
