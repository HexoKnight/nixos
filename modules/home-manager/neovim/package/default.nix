{ lib, pkgs, ... }@inputs:

let
  inherit (lib) mkOption types;

  neovimPackageModule = {config, ...}: {
    imports = [
      (import ./lspconfig.nix inputs)
      (import ./plugins.nix inputs)
    ];
    options = {
      vimlConfig = mkOption {
        description = "Main viml config (loaded after lua config).";
        type = types.lines;
        default = "";
      };
      luaConfig = mkOption {
        description = "Main lua config (loaded before vim config).";
        type = types.lines;
        default = "";
      };
      pluginPackages = mkOption {
        description = "Plugin packages.";
        type = types.listOf types.package;
        default = [];
      };
      extraPackages = mkOption {
        description = "Extra packages made available to neovim.";
        type = types.listOf types.package;
        default = [];
      };

      package = mkOption {
        description = "The package to use for the neovim binary.";
        type = types.package;
        default = pkgs.neovim-unwrapped;
      };
      finalPackage = mkOption {
        description = "Resulting configured neovim package.";
        type = types.package;
        readOnly = true;
      };
    };
    config =
    let
      neovimConfig = pkgs.neovimUtils.makeNeovimConfig {
        customRC = config.vimlConfig;
        plugins = config.pluginPackages;
      };
      neovimPackage = pkgs.wrapNeovimUnstable config.package (neovimConfig // {
        luaRcContent = config.luaConfig;
        wrapperArgs = ''--prefix PATH : "${lib.makeBinPath config.extraPackages}"'';
      });
    in
    {
      finalPackage = neovimPackage;
    };
  };
in
{
  options.neovim = mkOption {
    description = "Neovim package configurations.";
    type = types.attrsOf (types.submodule neovimPackageModule);
  };
}
