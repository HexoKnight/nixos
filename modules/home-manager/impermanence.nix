{ lib, pkgs, config, inputs, ... }:

let
  home-persist-root = "/persist/home/${config.home-inputs.username}";
  cfg = config.persist-home;
in
{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  options.persist-home =
  let
    impermanence-module = import "${inputs.impermanence}/home-manager.nix" { inherit pkgs config lib; };
    persistence-submodule = lib.head impermanence-module.options.home.persistence.type.nestedTypes.elemType.getSubModules {
      name = home-persist-root;
    };
  in
  {
    inherit (persistence-submodule.options) directories files;
  };

  config = lib.mkIf config.home-inputs.persistence {
    home.persistence.${home-persist-root} = {
      allowOther = true;
    } // cfg;
  };
}
