{ lib, config, options, ... }:

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
    assertions =
      let
        definitions = map (attrs: lib.attrsets.removeAttrs attrs [
          "packageOverrides" "perlPackageOverrides"
        ]) options.nixpkgs.config.definitions;
        checkMergeFail = path: attrsets:
          lib.foldr ({ name, value }: mergeFail:
            let
              newPath = path ++ [name];
            in
            if mergeFail != null then
              mergeFail
            else if lib.length value <= 1 then
              mergeFail
            else if lib.all lib.isAttrs value then
              checkMergeFail newPath value
            else
              newPath
          ) null (lib.attrsToList (lib.zipAttrs attrsets));

        mergeFail = checkMergeFail [] definitions;
      in
      [{
        assertion = mergeFail == null;
        message = ''
          the option 'nixpkgs.config.${lib.concatStringsSep "." mergeFail}' is defined more than once but its values will not merge :(
          one of them will overwrite the other
        '';
      }];

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
