{ lib, pkgs, config, ... }:

let
  cfg = config.setups.rust;
in
{
  options.setups.rust = {
    enable = lib.mkEnableOption "rust dev stuff";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".cargo"
      ];
    };

    home.packages = with pkgs; [
      rustc
      cargo
      rust-analyzer
      rustfmt
      clippy
    ];

    neovim.main.lspServers = {
      rust_analyzer = {
        extraPackages = with pkgs; [ rust-analyzer ];
      };
    };
  };
}
