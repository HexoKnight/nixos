{ lib, pkgs, config, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.neovim;

  neovimConfig = pkgs.neovimUtils.makeNeovimConfig {
    customRC = cfg.vimlConfig;
    plugins = cfg.pluginPackages;
  };
  neovimPackage = pkgs.wrapNeovimUnstable cfg.package (neovimConfig // {
    luaRcContent = cfg.luaConfig;
    wrapperArgs = ''--prefix PATH : "${lib.makeBinPath cfg.extraPackages}"'';
  });
in
{
  options.neovim = {
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

  config.neovim = {
    finalPackage = neovimPackage;
  };
}
