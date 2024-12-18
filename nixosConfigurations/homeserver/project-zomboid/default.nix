{ pkgs, config, ... }:

let
  # https://github.com/nix-community/steam-fetcher
  steam-fetcher-flake = builtins.getFlake "github:nix-community/steam-fetcher/12f66eafb7862d91b3e30c14035f96a21941bd9c";

  zomboid-server = pkgs.callPackage ./dedicated-server.nix {};
in
{
  config = {
    nixpkgs-overlays = [ steam-fetcher-flake.outputs.overlays.default ];

    nixpkgs.allowUnfreePkgs = [ "project-zomboid-server" "steamworks-sdk-redist" ];

    environment.systemPackages = [
      zomboid-server
    ];
  };
}
