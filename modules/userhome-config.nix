{ config, options, pkgs, lib, inputs, unstable-overlay, ... }:

with lib;
let
  users = config.userhome-config;
in {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  options.userhome-config = mkOption {
    default = {};
    description = "users to configure";
    type = let host-config = config.host-config; in types.attrsOf (types.submodule ({name, config, ...}: {
      options = {
        username = mkOption {
          type = types.str;
          default = name;
          description = "the user's username (defaults to the attrset's name)";
        };
        cansudo = mkOption {
          default = false;
          type = types.bool;
          description = "whether the user can use sudo";
        };
        persistence = mkEnableOption "whether to enable persistence";
        hasRebuildCommand = mkOption {
          default = true;
          type = types.bool;
          description = "whether the user gets a nice rebuild command";
        };
        hasPersistCommand = mkOption {
          default = true;
          type = types.bool;
          description = "whether the user gets a nice persist command";
        };
        personal-gaming = mkOption {
          default = false;
          description = "whether the user should have personal/gaming applications";
          type = types.bool;
          apply = val: assert (val -> host-config.desktop || throw "a user having personal-gaming requires the host to have a desktop"); val;
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

  config = mkIf (users != {}) {
    nixpkgs.overlays = [ unstable-overlay ];
    # required for persistence
    programs.fuse.userAllowOther = true;

    users.users = attrsets.mapAttrs (_: value: mkMerge [{
      name = value.username;
      extraGroups = lists.optional value.cansudo "wheel";
      packages = with pkgs; lists.optionals value.hasRebuildCommand [
        (writeShellScriptBin "rebuild" (builtins.readFile "${inputs.self}/rebuild.sh"))

        # required for the rebuild command
        (writeShellScriptBin "evalvar" (builtins.readFile "${inputs.self}/evalvar.sh"))
        unstable.nixVersions.nix_2_19
      ] ++ lists.optionals value.hasPersistCommand [
        (writeShellScriptBin "persist" (builtins.readFile "${inputs.self}/persist.sh"))
      ];
    } value.extraOptions]) users;

    home-manager.extraSpecialArgs = {
      inherit inputs unstable-overlay;
      system-config = config;
    };
    home-manager.users = attrsets.mapAttrs' (_: {username, ...}@value: {
      name = username;
      value = import ./home-manager/home.nix ({ inherit username; } // config.host-config // value);
    }) users;
  };
}
