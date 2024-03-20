{ config, pkgs, inputs, unstable-overlay, ... }:

with lib;
let cfg = config.user-config;
in {
    imports = [
        inputs.home-manager.nixosModules.home-manager
    ];

    options.user-config = {
        mutableUsers = mkOption {
            default = true;
            description = "literally just users.mutableUsers";
            type = types.bool;
        };
        users = mkOption {
            description = "users";
            type = types.attrsOf (submodule {
                options = {
                    home-module = {
                        default = import "${inputs.self}/modules/home.nix" { username = "nixos"; };
                        type = (import "${inputs.home-manager}/nixos/common.nix" { inherit config lib pkgs; }).options.home-manager.users.type.nestedTypes.elemType;
                    };
                };
            });
        };
    };

    config = {
        users.mutableUsers = cfg.mutableUsers;
        users.
    };
}