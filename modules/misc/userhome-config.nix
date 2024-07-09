{ config, options, pkgs, lib, inputs, ... }:

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
    type =
    let
      host-config = config.host-config;
    in
    types.attrsOf (types.submodule ({name, config, ...}: {
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
    }));
  };

  config = mkIf (users != {}) {
    # required for persistence
    programs.fuse.userAllowOther = true;

    users.users = attrsets.mapAttrs (_: {username, ...}@value: mkMerge [{
      name = username;
      extraGroups = lists.optional value.cansudo "wheel";
      packages = with pkgs;
        lists.optional value.hasRebuildCommand local.rebuild ++
        lists.optional value.hasPersistCommand local.persist;
    } value.extraOptions]) users;

    home-manager.extraSpecialArgs = {
      inherit inputs;
      system-config = config;
    };
    home-manager.users = attrsets.mapAttrs' (_: {username, ...}@value: {
      name = username;
      value = import "${inputs.self}/modules/home-manager/home.nix" ({ inherit username; } // config.host-config // value);
    }) users;
  };
}
