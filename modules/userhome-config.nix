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
      type = types.attrsOf (types.submodule ({name, config, ...}: {
        options = {
          username = mkOption {
            type = types.str;
            default = name;
            description = "the user's username (defaults to the attrset name)";
          };
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
          personal-gaming = mkOption {
            default = false;
            description = "whether the user should have personal/gaming applications";
            type = types.bool;
            apply = val: assert (val -> cfg.host.desktop || throw "a user having personal-gaming requires the host to have a desktop"); val;
          };
          extraOptions = mkOption {
            type = types.attrs;
            default = {};
            description = "extra options passed to users.users.<name>";
          };
        };
        config = {
        };
      }));
    };
  };

  config = mkIf (cfg.enable) {
    nixpkgs.overlays = [ unstable-overlay ];

    users.mutableUsers = cfg.mutableUsers;
    users.users = attrsets.mapAttrs (_: value: mkMerge [{
      name = value.username;
      extraGroups = lists.optional value.cansudo "wheel";
      packages = with pkgs; lists.optionals value.hasRebuildCommand [
        (writeShellScriptBin "rebuild" (builtins.readFile "${inputs.self}/rebuild.sh"))

        # required for the rebuild command
        (writeShellScriptBin "evalvar" (builtins.readFile "${inputs.self}/evalvar.sh"))
        unstable.nixVersions.nix_2_19
      ];
    } value.extraOptions]) cfg.users;

    home-manager.extraSpecialArgs = {inherit inputs unstable-overlay;};
    home-manager.users = attrsets.mapAttrs' (_: {username, ...}@value: {
      name = username;
      value = import ./home.nix ({ inherit username; } // cfg.host // value);
    }) cfg.users;
  };
}
