{ config, options, pkgs, lib, inputs, unstable-overlay, ... }:

with lib;
let
    cfg = config.common-config;
in {
    imports = [
        inputs.home-manager.nixosModules.home-manager
    ];

    options.common-config = {
        mutableUsers = mkOption {
            default = true;
            description = "literally just users.mutableUsers";
            type = types.bool;
        };
        host = mkOption {
            description = "host information";
            type = types.attrsOf (types.submodule {
                desktop = mkOption {
                    default = false;
                    description = "whether the host has a desktop";
                    type = types.bool;
                };
            });
        };
        users = mkOption {
            description = "users";
            type = types.attrsOf (types.submodule {
                options = {
                    # home-module = mkOption {
                    #     default = import "${inputs.self}/modules/home.nix" { username = "nixos"; };
                    #     type = (import "${inputs.home-manager}/nixos/common.nix" { inherit config lib pkgs; }).options.home-manager.users.type.nestedTypes.elemType;
                    # };
                };
            });
        };
    };

    config = {
        users.mutableUsers = cfg.mutableUsers;
        home-manager.extraSpecialArgs = {inherit inputs unstable-overlay;};
        # home-manager.users = mkAliasAndWrapDefinitions (attrsets.mapAttrs (name: value: value.home-module)) (options.common-config.users);
        home-manager.users = attrsets.mapAttrs (name: value: import ./home.nix ({ username = name; } // cfg.host // value)) cfg.users;
    };
}