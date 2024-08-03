{ lib, pkgs, config, ... }:

{
  imports = [
    # define neovim options
    ./package.nix ./plugins.nix ./lspconfig.nix
    # configure neovim using said options
    ./config.nix ./plugins
  ];

  neovim = {
    package = pkgs.unstable.neovim-unwrapped;
    lspServers = {
      rust_analyzer = {
        extraPackages = with pkgs; [ rust-analyzer ];
      };
      nil_ls = {
        extraPackages = with pkgs; [ nil ];
      };
    };
  };

  home.packages = [ config.neovim.finalPackage ];

  home.sessionVariables = {
    EDITOR = lib.getExe (pkgs.writeShellScriptBin "remote-nvim-edit" ''
      exec ${lib.getExe pkgs.neovim-remote} -s --remote-wait "$@"
    '');
  };
}
