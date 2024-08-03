{ lib, pkgs, config, ... }:

let
  inherit (lib) mkOption types;

  lspServers = config.neovim.lspServers;
in
{
  options.neovim = {
    lspServers = mkOption {
      description = "Lsp servers to install (and configure) from nvim-lspconfig.";
      type = types.attrsOf (types.submodule ({name, config, ...}: {
        options = {
          serverName = mkOption {
            description = "Name of the lsp server (according to lspconfig).";
            type = types.str;
            default = name;
          };
          config = mkOption {
            description = "Lua config passed to server setup.";
            type = types.str;
            default = "{}";
          };
          extraPackages = mkOption {
            description = "Extra packages made available to neovim.";
            type = types.listOf types.package;
            default = [];
          };
        };
      }));
      default  = {};
    };
  };

  config.neovim = {
    pluginsWithConfig = [{
      plugin = pkgs.vimPlugins.nvim-lspconfig;
      type = "lua";
      config =
      builtins.concatStringsSep "\n" (
      [ "local lspconfig = require('lspconfig')" ]
      ++ lib.mapAttrsToList (_name: { serverName, config, ... }:
        "lspconfig[ [[${serverName}]] ].setup(${config})"
      ) lspServers);
    }];
    extraPackages = builtins.concatLists
      (lib.mapAttrsToList (_name: value: value.extraPackages) lspServers);
  };
}
