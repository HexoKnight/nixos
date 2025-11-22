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

    neovim.main.lspServers = {
      rust_analyzer = {
        # rustup can be installed with rustup
        # extraPackages = [ pkgs.rust-analyzer ];
      };
    };
  };
}
