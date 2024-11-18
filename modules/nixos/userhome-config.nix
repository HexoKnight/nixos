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
        extraHmConfig = mkOption {
          description = "extra home manager config";
          type = types.deferredModule;
          default = [];
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
    users.users = attrsets.mapAttrs (_: {username, ...}@value: mkMerge [{
      name = username;
      extraGroups = lists.optional value.cansudo "wheel";
      packages = with pkgs;
        lists.optional value.hasPersistCommand local.persist;
    } value.extraOptions]) users;

    home-manager.extraSpecialArgs = { inherit inputs; };
    home-manager.users = attrsets.mapAttrs' (_: {username, ...}@value: {
      name = username;
      value = {
        imports = [
          ../home-manager
          value.extraHmConfig
        ];

        config = {
          setups = {
            config = {
              inherit username;
              inherit (config.host-config) disable-touchpad;
            };
            inherit (config.host-config) desktop;
            impermanence = value.persistence;
            inherit (value) personal-gaming;
          };
        };
      };
    }) users;
  };
}
