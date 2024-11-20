{ lib, config, ... }:

# would use `nixpkgs.config.allowUnfreePkgs` but nixpkgs.config doesn't allow nested options :/
{
  options = {
    nixpkgs.allowUnfreePkgs = lib.mkOption {
      description = "List of package names or predicates to allow despite being unfree.";
      type =
        let
          inherit (lib) types;
          predType = types.functionTo types.bool;
          elemType = types.either types.str predType;
        in
        types.coercedTo predType lib.singleton (types.listOf elemType);
      default = [];
    };
  };

  config = {
    nixpkgs = lib.mkIf (config.nixpkgs.allowUnfreePkgs != []) {
      config.allowUnfreePredicate = pkg:
        lib.any (val:
          if lib.isString val then
            val == lib.getName pkg
          else if lib.isFunction val then
            val pkg
          else
            throw "unreachable"
        ) config.nixpkgs.allowUnfreePkgs;
    };
  };
}
