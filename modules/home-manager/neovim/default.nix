{ lib, pkgs, ... }:

{
  imports = [ ./plugins ./config.nix ];
  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    extraLuaConfig = /* lua */ ''
    '';
    extraPackages = with pkgs; [
      rust-analyzer
      nil
    ];
  };

  home.sessionVariables = {
    EDITOR = lib.getExe (pkgs.writeShellScriptBin "remote-nvim-edit" ''
      exec ${lib.getExe pkgs.neovim-remote} -s --remote-wait "$@"
    '');
  };
}
