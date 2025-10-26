{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.rust;
in
{
  options.setups.tooling.rust = {
    enable = lib.mkEnableOption "rust dev stuff";

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
        cfg.cargoDir
      ];
    };

    home.sessionVariables = {
      CARGO_HOME = "$HOME/${cfg.cargoDir}";
    };

    home.sessionPath = [
      "$HOME/${cfg.cargoDir}/bin"
    ];

    home.packages = with pkgs.unstable; [
      rustc
      cargo
      rust-analyzer
      rustfmt
      clippy

      # a cc is necessary for building rust programs
      gcc
    ];

    neovim.main.lspServers = {
      rust_analyzer = {
        # already included in home.packages above
        # extraPackages = with pkgs; [ rust-analyzer ];
      };
    };
  };
}
