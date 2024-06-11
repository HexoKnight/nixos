{ lib, pkgs, ... }:

{
  programs.neovim.plugins =
  let
    pluginAttrsToList = lib.mapAttrsToList (name: value:
      let
        plugin = pkgs.vimPlugins.${name};
      in
      if ! builtins.isAttrs value then
        { inherit plugin; config = value; }
      else if value ? gui-config then
        {
          inherit plugin;
          config = ''
            ${value.config or ""}
            if has("gui_running")
              ${value.gui-config}
            endif
          '';
        } // builtins.removeAttrs value [ "config" "gui-config" ]
      else
        { inherit plugin; } // value
    );
  in
  pluginAttrsToList (lib.dir.mapImportNixDirWithoutDefault (_name: value: value) ./. // { })

  ++ (with pkgs.vimPlugins; [
    {
      plugin = nvim-treesitter.withAllGrammars;
      type = "lua";
      config = /* lua */ ''
        require('nvim-treesitter.configs').setup {
          highlight = { enable = true },
          additional_vim_regex_highlighting = false,
        }
      '';
    }
  ]);
}
