{ lib, pkgs, ... }:

{
  imports = [ ./plugins ./config.nix ];
  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    extraLuaConfig = /* lua */ ''
    '';
  };
}
