{ lib, pkgs, ... }:

{
  imports = [ ./plugins ./config.nix ];
  programs.neovim = {
    enable = true;
    extraLuaConfig = /* lua */ ''
    '';
  };
}
