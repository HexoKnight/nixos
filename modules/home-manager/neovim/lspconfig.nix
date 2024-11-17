{ lib, pkgs, ... }:

{ config, ... }:

let
  inherit (lib) mkOption types;

  enabledLspServers = lib.filterAttrs (_name: server: server.enable) config.lspServers;
in
{
  options = {
    lspServers = mkOption {
      description = "Lsp servers to install (and configure) from nvim-lspconfig.";
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = lib.mkEnableOption "this lsp server config" // { default = true; };
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

  config = lib.mkIf (config.lspServers != {}) {
    pluginsWithConfig = [{
      plugin = pkgs.vimPlugins.nvim-lspconfig;
      type = "lua";
      config = (/* lua */ ''
        local lspconfig = require('lspconfig')
        local capabilities = vim.lsp.protocol.make_client_capabilities()

        local hasCmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
        if hasCmp then
          capabilities = vim.tbl_deep_extend('force', capabilities, cmp_nvim_lsp.default_capabilities())
        end

        local defaultSettings = {
          capabilities = capabilities,
        }
      '')
      + builtins.concatStringsSep "\n" (lib.mapAttrsToList (_name: { serverName, config, ... }:
        "lspconfig[ [[${serverName}]] ].setup(vim.tbl_deep_extend('force', defaultSettings, ${config}))"
      ) enabledLspServers);
    }];
    extraPackages = builtins.concatLists
      (lib.mapAttrsToList (_name: value: value.extraPackages) enabledLspServers);
  };
}
