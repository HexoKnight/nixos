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
    nixpkgs.config.allowUnfreePredicate = pkg:
    let
      name = lib.getName pkg;
    in
    lib.any (val:
      if lib.isString val then
        name == val
      else # if lib.isFunction then
        val pkg
    ) config.nixpkgs.allowUnfreePkgs;
  };
}
