{ lib, config, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.neovim;

  pluginConfigs = lib.foldl (acc: plugin:
    if plugin.config == "" then acc else
    acc // {
      ${plugin.type} = acc.${plugin.type} + "\n" + plugin.config;
    }
  ) {
    viml = "";
    lua = "";
  } cfg.pluginsWithConfig;

  pluginPackages = map (p: p.plugin) cfg.pluginsWithConfig;
in
{
  options.neovim = {
    pluginsWithConfig = mkOption {
      description = "Plugins with associated config.";
      type = types.listOf (types.submodule {
        options = {
          plugin = mkOption {
            description = "Plugin package.";
            type = types.package;
            default = "";
          };
          config = mkOption {
            description = "Plugin `type` config.";
            type = types.lines;
            default = "";
          };
          type = mkOption {
            description = "Plugin config type.";
            type = types.enum [ "viml" "lua" ];
            default = "viml";
          };
        };
      });
      default = [];
    };
  };

  config.neovim = {
    vimlConfig = lib.mkBefore pluginConfigs.viml;
    luaConfig = lib.mkBefore pluginConfigs.lua;
    inherit pluginPackages;
  };
}
