{ lib, pkgs, config, ... }:

let
  cfg = config.setups.neovim;
in
{
  imports = [
    ./config
    ./plugins
  ];

  options.setups.neovim = {
    enable = lib.mkEnableOption "neovim";
  };

  config = lib.mkIf cfg.enable {
    neovim.main = {
      name = "nvim";
      package = pkgs.neovim-unwrapped;
      lspServers = {
        nil_ls = {
          extraPackages = with pkgs; [ nil ];
          config.settings.nil = {
            nix.flake = {
              autoArchive = true;
              autoEvalInputs = false;
            };
          };
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

    home.packages = [ config.neovim.main.finalPackage ];

    home.sessionVariables = {
      EDITOR = lib.getExe (pkgs.writeShellScriptBin "remote-nvim-edit" ''
        exec ${lib.getExe pkgs.neovim-remote} -s --remote-wait "$@"
      '');
    };
  };
}
