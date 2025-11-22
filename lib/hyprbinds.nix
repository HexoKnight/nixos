lib:

rec {
  mkBind = dispatcher: args: {
    inherit dispatcher args;
  };

  mkNoArgBind = dispatcher: {
    inherit dispatcher;
  };

  mkExec = mkBind "exec";

  mkMouseBind = withFlags "m" mkNoArgBind;

  mergeFlags = flags: lib.concatStrings (lib.unique (lib.concatMap lib.stringToCharacters flags));

  addFlags = flags: { oldFlags ? "", ...}@bind:
    bind // { flags = mergeFlags [oldFlags flags]; };

  withFlags = flags: bind:
    if lib.isFunction bind then arg: withFlags flags (bind arg)
    else addFlags flags bind;

  repeating = withFlags "e";
}
