{ lib, pkgs, ... }:

{
  imports = [ ./plugins ./config.nix ];
  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    extraLuaConfig = /* lua */ ''
    '';
  };

  home.sessionVariables = {
    EDITOR = lib.getExe (pkgs.writeShellApplication {
      name = "remote-nvim-open";
      runtimeInputs = [ ];
      text = ''
        exec nvim --server "''${NVIM:-}" --remote "$@"
      '';
    });
  };
}
