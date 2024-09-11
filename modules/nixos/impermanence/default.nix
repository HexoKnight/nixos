{ lib, inputs, config, ... }:

let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.persist;

  persist-root = cfg.root;
  system-persist-root = "${persist-root}/system";

  persistence-options = (import "${inputs.self}/modules/lib/impermanence.nix" { inherit lib; }).override (final: prev: {
    # TODO: add extensions
  });

  filterRecursive = {
    filter ? _:_:true,
    filterAttrs ? filter,

    prefix ? [],
  }@attrs: value:
    let
      newPrefix = next: prefix ++ [ next ];
      recurse = next: filterRecursive (attrs // {
        prefix = newPrefix next;
      });
    in
    if lib.isAttrs value then
      lib.mapAttrs recurse (lib.filterAttrs (n: filterAttrs (newPrefix n)) value)
    else if lib.isList value then
      lib.imap0 recurse (lib.ifilter0 (i: filter (newPrefix i)) value)
    else value;

  # would extend persistence options instead but the coercedTo type
  # cannot be merged :/
  sanitised-cfg = filterRecursive {
    filter = _: v: v != null;
    filterAttrs = p: v: ! (
      v == null ||
      ( (lib.length p < 2 || lib.elemAt p (lib.length p - 2) != "users") &&
        lib.elem (lib.last p) [
          "backup"
        ]
      ));
  } cfg;
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
    ./default-setup.nix
  ];

  options.persist = {
    enable = mkEnableOption "system persistence (and home persistence if it is configured in home manager)";
    root = mkOption {
      description = "The root directory that persisted files will be placed in";
      type = types.str;
    };
    system = {
      inherit (persistence-options.options) directories files;
    };
    inherit (persistence-options.options) users;
  };

  config = lib.mkIf cfg.enable {
    ### SYSTEM PERSISTENCE

    environment.persistence.${system-persist-root} = {
      hideMounts = true;
      inherit (sanitised-cfg.system) directories files;
    };
    # so that home files are stored at
    # ${persist-root}/home/<username>
    environment.persistence.${persist-root} = {
      hideMounts = true;
      inherit (sanitised-cfg) users;
    };

    ### HOME MANAGER PERSISTENCE

    home-manager.sharedModules = lib.singleton {
      persist-home.usedByOS = true;
    };

    persist.users = lib.mapAttrs (_name: config:
      lib.mkIf (config.persist-home.enable or false) {
        inherit (config.persist-home) directories files;
        # FIXME: infinite recursion :(
        # home = config.home.homeDirectory;
      }
    ) config.home-manager.users;
  };
}
