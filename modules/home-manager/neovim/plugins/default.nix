{ lib, pkgs, ... }:

{
  neovim.pluginsWithConfig =
  let
    pluginAttrsToList = lib.mapAttrsToList (name: value:
      let
        plugin = pkgs.vimPlugins.${name};
      in
      if ! builtins.isAttrs value then
        let
          luaOptions = builtins.match "(--lua([[:blank:]]+setup([[:blank:]]+([^[:space:]]+))?)?)?.*" value;
          isLua = builtins.elemAt luaOptions 0 != null;
          doLuaSetup = builtins.elemAt luaOptions 1 != null;
          customLuaSetupName = builtins.elemAt luaOptions 3;
          luaSetupName =
            if customLuaSetupName != null
            then customLuaSetupName
            else name;

          type = if isLua then "lua" else "viml";
          config = if !isLua then value else
            if !doLuaSetup then value else ''
              require('${luaSetupName}').setup(${value})
            '';
        in
        {
          inherit plugin type config;
        }
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
  pluginAttrsToList (
    lib.concatMapAttrs (filename: filetype:
      let
        toBeImported = filename != "default.nix" && (isDir || options ? ${extension});

        fullPath = lib.path.append ./. "./${filename}";
        isDir = filetype == "directory";

        filenameMatch = builtins.match ''(.*)\.(.*)'' filename;
        basenameStem = builtins.elemAt filenameMatch 0;
        extension = builtins.elemAt filenameMatch 1;

        attr = if isDir then {
          ${filename} = import fullPath;
        } else {
          ${basenameStem} = options.${extension};
        };

        options = {
          "nix" =
            let value = import fullPath; in
            if builtins.isFunction value then value pkgs else value;
          "vim" = {
            type = "viml";
            config = builtins.readFile fullPath;
          };
          "lua" = {
            type = "lua";
            config = builtins.readFile fullPath;
          };
        };
      in
      lib.optionalAttrs toBeImported attr
    ) (builtins.readDir ./.)
    // {
    undotree = /* vim */ ''
      map <silent> <F3> :UndotreeToggle<CR>
    '';
    nerdtree = /* vim */ ''
      map <silent> <F4> :NERDTreeToggle<CR>
    '';
    vim-easymotion = /* vim */ ''
      " change easymotion prefix from \\ to \
      map <Leader> <Plug>(easymotion-prefix)
    '';
    quick-scope = /* vim */ ''
      nmap <leader>q <plug>(QuickScopeToggle)
      let g:qs_enable=1
      let g:qs_hi_priority = 2
      let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']
      let g:qs_buftype_blacklist = ['terminal']
      let g:qs_filetype_blacklist = ['startify']
    '';
    vim-windowswap = /* vim */ ''
      let g:windowswap_map_keys = 0
      nnoremap <silent> <C-w>y :call WindowSwap#MarkWindowSwap()<CR>
      nnoremap <silent> <C-w>p :call WindowSwap#DoWindowSwap()<CR>
    '';
    vim-sleuth = {};

    statuscol-nvim = /* lua */ ''
      --lua setup statuscol
      {
        relculright = true,
        segments = {
          { text = { require("statuscol.builtin").foldfunc }, click = "v:lua.ScFa" },
          { text = { "%s" }, click = "v:lua.ScSa" },
          {
            text = { require("statuscol.builtin").lnumfunc, " " },
            condition = { true, require("statuscol.builtin").not_empty },
            click = "v:lua.ScLa",
          },
        },
      }
    '';

    # or presence-nvim
    vimsence = /* vim */ ''
    '';
    nvim-web-devicons = /* lua */ ''
      --lua
      require('nvim-web-devicons').setup({})

      function _G.webDevIcons(path)
        local filename = vim.fn.fnamemodify(path, ':t')
        local extension = vim.fn.fnamemodify(path, ':e')
        return require'nvim-web-devicons'.get_icon(filename, extension, { default = true })
      end
      vim.cmd[[
        function! StartifyEntryFormat() abort
          return 'v:lua.webDevIcons(absolute_path) . " " . entry_path'
        endfunction
      ]]
    '';
    nvim-surround = /* lua */ ''
      --lua setup
    '';
    comment-nvim = /* lua */ ''
      --lua setup Comment
    '';
    indent-blankline-nvim = /* lua */ ''
      --lua setup ibl
      {
        indent = {
        },
        scope = {
          show_exact_scope = true,
        },
        exclude = {
          filetypes = { "startify" },
        },
      }
    '';
    # configured in main config because it needs to be done before other stuff
    neovim-ayu = {};
  })

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
