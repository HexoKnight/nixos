{ lib, pkgs, config, ... }:

{
  imports = [
    # define neovim options
    ./package.nix ./plugins.nix ./lspconfig.nix
    # configure neovim using said options
    ./config ./plugins
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
      vimls = {
        extraPackages = with pkgs; [ vim-language-server ];
      };
    };
  };

  persist-home = {
    directories = [
      # stores transient state that could be removed without
      # too much issue (undos, swaps, shada, etc.)
      ".local/state/nvim"
      # stores more permanent state that should not be
      # removed so easily (sessions, etc.)
      ".local/share/nvim"
    ];
  };

  home.packages = [ config.neovim.finalPackage ];

  home.sessionVariables = {
    EDITOR = lib.getExe (pkgs.writeShellScriptBin "remote-nvim-edit" ''
      exec ${lib.getExe pkgs.neovim-remote} -s --remote-wait "$@"
    '');
  };
}
