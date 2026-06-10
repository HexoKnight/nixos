{ lib, config, ... }:

let
  t = lib.types;

  # (String -> a -> b) -> { [String] :: [a] } -> [b]
  mapAttrListsToList =
    f: attrs:
    let
      lists = lib.mapAttrsToList (name: lib.map (f name)) attrs;
    in
    lib.concatLists lists;

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

  bindAction = t.submodule (
    { name, config, ... }:
    {
      options = {
        dispatcher = lib.mkOption {
          description = "Lua dispatcher (hl.dsp.*) to be invoked";
          type = t.strMatching "[^,]+";
        };
        args = lib.mkOption {
          description = "Dispatcher args";
          default = [ ];
          type = t.either luaValueType (t.listOf luaValueType);
        };
        callback = lib.mkOption {
          description = "Whether the dispatcher is evaluated at runtime rather than bind-time";
          default = false;
          type = t.bool;
        };
        rawLua = lib.mkOption {
          description = "Raw Lua to be passed as the dispatcher";
          type = luaValueType;
          default =
            let
              dispatcher = "hl.dsp.${config.dispatcher}(${
                lib.concatMapStringsSep ", " toLuaExpr (lib.toList config.args)
              })";
            in
            if config.callback then
              lib.mkLuaInline "function() hl.dispatch(${dispatcher}) end"
            else
              lib.mkLuaInline dispatcher;
        };
        flags = lib.mkOption {
          description = "Bind flags";
          default = [ ];
          type = t.listOf t.str;
        };
      };
    }
  );
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
      type = t.attrsOf bindAction;
    };

    submapBinds = lib.mkOption {
      description = "Attribute set of Hyprland lua submaps with bindings";
      default = { };
      type = t.attrsOf (t.attrsOf bindAction);
    };
  };

  config = {
    lib.hypr = {
      binds =
        let
          functorise = f: arg: if lib.isFunction arg then newArg: (functorise f) (arg newArg) else f arg;
        in
        rec {
          mkBind = dispatcher: args: {
            inherit dispatcher args;
          };

          mkNoArgBind = dispatcher: {
            inherit dispatcher;
          };

          mkExec = prog: mkBind "exec_cmd" [ prog ];

          mkMouseBind = withFlag "mouse" mkNoArgBind;

          asCallback = functorise (bind: bind // { callback = true; });

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

          withFlags = flags: functorise (addFlags flags);
          withFlag = flag: withFlags [ flag ];

          repeating = withFlag "repeating";
        };
    };
    wayland.windowManager.hyprland =
      let
        # { [String] :: [bindAction] } -> [{ _args :: [...] }]
        mapBinds = lib.mapAttrsToList (
          key: bind: {
            _args = [
              key
              bind.rawLua
            ]
            ++ lib.optional (bind.flags != [ ]) (lib.genAttrs bind.flags (_: true));
          }
        );
      in
      {
        settings.on = mapAttrListsToList (event: callback: {
          _args = [
            event
            callback
          ];
        }) cfg.events;

        settings.bind = mapBinds cfg.binds;

        submaps =
          let
            submaps = lib.mapAttrs (_: binds: {
              settings.bind = mapBinds binds;
            }) cfg.submapBinds;
          in
          submaps;
      };
  };
}
