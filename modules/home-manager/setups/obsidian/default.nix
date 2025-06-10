{ lib, pkgs, config, ... }:

let
  cfg = config.setups.obsidian;

  toLua = lib.generators.toLua {};

  # https://github.com/epwalsh/obsidian.nvim/blob/14e0427bef6c55da0d63f9a313fd9941be3a2479/lua/obsidian/workspace.lua#L4-L9
  workspacesType = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
    options = {
      name = lib.mkOption {
        description = "Workspace name. Defaults to attr name";
        type = lib.types.str;
        default = name;
      };
      path = lib.mkOption {
        description = "Workspace path.";
        type = lib.types.pathWith { inStore = false; };
      };
      strict = lib.mkOption {
        description = "Whether the workspace root should be `path` rather than the valut root.";
        type = lib.types.bool;
        default = false;
      };
      overrides = lib.mkOption {
        description = "Override config for this workspace.";
        type = settingsType;
        default = {};
      };
    };
  }));
  # https://github.com/epwalsh/obsidian.nvim/blob/14e0427bef6c55da0d63f9a313fd9941be3a2479/lua/obsidian/config.lua#L6-L34
  settingsType = lib.types.attrsOf lib.types.anything;
in
{
  options.setups.obsidian = {
    enable = lib.mkEnableOption "Obsidian app and neovim plugin";

    plugin = {
      findWorkspaces = lib.mkOption {
        description = "A lua expression (to be wrapped in a function) that returns obsidian-nvim workspaces. Run at neovim startup.";
        type = lib.types.str;
        default = "return nil";
      };
      workspaces = lib.mkOption {
        description = ''
          List of obsidian-nvim workspaces (not necessarily Obsidian vaults). See:
          https://github.com/epwalsh/obsidian.nvim?tab=readme-ov-file#configuration-options
        '';
        type = workspacesType;
      };
      config = lib.mkOption {
        description = ''
          Config for obsidian-nvim. See:
          https://github.com/epwalsh/obsidian.nvim?tab=readme-ov-file#configuration-options
        '';
        type = settingsType;
        default = {};
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.obsidian ];
    nixpkgs.allowUnfreePkgs = [
      "obsidian"
    ];

    neovim.main = {
      pluginsWithConfig = [
        { plugin = pkgs.vimPlugins.obsidian-nvim;
          type = "lua";
          config = /* lua */ ''
            local workspaces = (${toLua (lib.attrValues cfg.plugin.workspaces)})
            local dynamic_workspaces = (function() ${cfg.plugin.findWorkspaces} end)()

            if dynamic_workspaces then
              -- concat workspaces with dynamic_workspaces
              table.foreach(dynamic_workspaces, function(i, item) table.insert(workspaces, item) end)
            end

            local args = (${toLua cfg.plugin.config})
            args.workspaces = workspaces

            require('obsidian').setup(args)
          '';
        }
      ];
    };
  };
}
