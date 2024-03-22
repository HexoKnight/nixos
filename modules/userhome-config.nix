{ config, options, pkgs, lib, inputs, unstable-overlay, ... }:

with lib;
let
    cfg = config.userhome-config;
in {
    imports = [
        inputs.home-manager.nixosModules.home-manager
    ];

    options.userhome-config = {
        enable = mkEnableOption "common configuration";
        mutableUsers = mkOption {
            default = true;
            description = "literally just users.mutableUsers";
            type = types.bool;
        };
        host = {
            desktop = mkOption {
                default = false;
                description = "whether the host has a desktop";
                type = types.bool;
            };
        };
        users = mkOption {
            description = "users";
            type = types.attrsOf (types.submodule {
                options = {
                    cansudo = mkOption {
                        default = false;
                        type = types.bool;
                        description = "whether the user can use sudo";
                    };
                    hasRebuildCommand = mkOption {
                        default = true;
                        type = types.bool;
                        description = "whether the user gets a nice rebuild command";
                    };
                    extraGroups = mkOption {
                        type = types.listOf types.str;
                        default = [];
                        description = "the user's auxiliary groups";
                    };
                    # home-module = mkOption {
                    #     default = import "${inputs.self}/modules/home.nix" { username = "nixos"; };
                    #     type = (import "${inputs.home-manager}/nixos/common.nix" { inherit config lib pkgs; }).options.home-manager.users.type.nestedTypes.elemType;
                    # };
                };
            });
        };
    };

    config = mkIf (cfg.enable) {
        nixpkgs.overlays = [ unstable-overlay ];

        users.mutableUsers = cfg.mutableUsers;
        users.users = attrsets.mapAttrs (name: value: {
            extraGroups = value.extraGroups ++ (lists.optional value.cansudo "wheel");
            packages = with pkgs; lists.optionals value.hasRebuildCommand [
                (writeShellScriptBin "rebuild" (builtins.readFile "${inputs.self}/rebuild.sh"))

                # required for the rebuild command
                (writeShellScriptBin "evalvar" (builtins.readFile "${inputs.self}/evalvar.sh"))
                unstable.nixVersions.nix_2_19
            ];
        }) cfg.users;

        home-manager.extraSpecialArgs = {inherit inputs unstable-overlay;};
        # home-manager.users = mkAliasAndWrapDefinitions (attrsets.mapAttrs (name: value: value.home-module)) (options.userhome-config.users);
        home-manager.users = attrsets.mapAttrs (name: value: import ./home.nix ({ username = name; } // cfg.host // value)) cfg.users;
    };
}