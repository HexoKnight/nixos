{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.rust;
in
{
  options.setups.tooling.rust = {
    enable = lib.mkEnableOption "rust dev stuff";

    rustupDir = lib.mkOption {
      description = "the location (relative to $HOME) of rustup's home ($RUSTUP_HOME)";
      type = lib.types.pathWith {
        absolute = false;
        inStore = false;
      };
      default = ".local/share/rustup";
    };
    cargoDir = lib.mkOption {
      description = "the location (relative to $HOME) of cargo's home ($CARGO_HOME)";
      type = lib.types.pathWith {
        absolute = false;
        inStore = false;
      };
      default = ".local/share/cargo";
    };
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        cfg.rustupDir
        cfg.cargoDir
      ];
    };

    home.sessionVariables = {
      RUSTUP_HOME = "$HOME/${cfg.rustupDir}";
      CARGO_HOME = "$HOME/${cfg.cargoDir}";
    };

    home.sessionPath = [
      "$HOME/${cfg.cargoDir}/bin"
    ];

    home.packages = [
      pkgs.rustup

      # a cc is necessary for building rust programs
      pkgs.gcc
    ];

    programs.bacon = {
      enable = true;
      settings = {
        default_job = "clippy";
        keybindings = {
          j = "scroll-lines(1)";
          k = "scroll-lines(-1)";
          ctrl-d = "scroll-pages(0.5)";
          ctrl-u = "scroll-pages(-0.5)";
          g = "scroll-to-top";
          shift-g = "scroll-to-bottom";
        };
      };
    };

    neovim.main.lspServers = {
      rust_analyzer = {
        config.settings.rust-analyzer = {
          check.command = "clippy";
        };
      };
    };
  };
}
