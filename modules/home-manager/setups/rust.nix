{ lib, pkgs, config, ... }:

let
  cfg = config.setups.rust;

  cargoDir = ".local/share/cargo";
in
{
  options.setups.rust = {
    enable = lib.mkEnableOption "rust dev stuff";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        cargoDir
      ];
    };

    home.sessionVariables = {
      CARGO_HOME = "$HOME/${cargoDir}";
    };

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
