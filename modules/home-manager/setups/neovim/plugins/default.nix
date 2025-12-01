{ lib, pkgs, ... }:

let
  pluginAttrsToList = vimPlugins: lib.mapAttrsToList (name: value:
    let
      pkgPlugin = vimPlugins.${name};
    in
    if builtins.isString value then
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
            require('${luaSetupName}').setup(${value}
            )
          '';
      in
      {
        plugin = pkgPlugin;
        inherit type config;
      }
    else if builtins.isAttrs value then
      let
        plugin = lib.pipe (value.plugin or pkgPlugin) (
          lib.optional (value ? override)
            (p: p.overrideAttrs value.override)
          ++ lib.optional (value ? postPatch)
            (p: p.overrideAttrs (final: prev: {
              postPatch = prev.postPatch or "" + value.postPatch;
            }))
        );
      in
      builtins.removeAttrs value [ "override" "postPatch" ] // { inherit plugin; }
    else throw "plugin attr '${name}' must be a string or attrset"
  );

  vimPlugins = pkgs.vimPlugins;
in
{
  lib.neovim = {
    inherit pluginAttrsToList;
  };

  neovim.main.pluginsWithConfig =
  pluginAttrsToList vimPlugins (
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
    vim-eunuch = {};

    nvim-cmp = /* lua */ ''
      --lua
      local cmp = require('cmp')

      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      cmp.setup({
        enabled = true,
        snippet = {
          expand = function(args)
            -- require('luasnip').lsp_expand(args.body)
            vim.snippet.expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              if #cmp.get_entries() == 1 then
                cmp.confirm({ select = true })
              else
                cmp.select_next_item()
              end
            elseif has_words_before() then
              cmp.complete()
              if #cmp.get_entries() == 1 then
                cmp.confirm({ select = true })
              end
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
        }, {
          { name = 'buffer' },
        }),
      })
    '';
    cmp-nvim-lsp = {};

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

    telescope-nvim = /* lua */ ''
      --lua setup telescope
    '';

    neocord = {
      override = final: prev: {
        # until https://github.com/IogaMaster/neocord/pull/27 is merged
        patches = prev.patches or [] ++ lib.singleton (pkgs.fetchpatch {
          url = "https://github.com/IogaMaster/neocord/commit/aac04403d84554ac42b547ddcc77f45935aabd70.patch";
          hash = "sha256-nTYkoXBS4CyqNX9uuDZHbpGUkdXhxDZ8PvseD1/BIzw=";
        });
      };
      postPatch = ''
        # add Startify as a dashboard
        substituteInPlace lua/neocord/filetypes/dashboards.lua \
          --replace-fail \
          'return {' \
          'return { ["startify"] = "Startify",'
      '';
      type = "lua";
      config = /* lua */ ''
        require'neocord'.setup{
          global_timer = true,
          logo = 'https://icons.iconarchive.com/icons/papirus-team/papirus-apps/256/nvim-icon.png',
        }
      '';
    };
    git-conflict-nvim = /* lua */ ''
      --lua setup git-conflict
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
    neovim-ayu = /* lua */ ''
      --lua
      local colors = require('ayu.colors')
      colors.generate()

      require("ayu").setup({
        terminal = false,
        overrides = {
          Normal = { bg = colors.black },
          LineNr = { fg = colors.comment },
          FoldColumn = { bg = colors.black },
          -- QuickScopePrimary = { bg = colors.selection_inactive },
        },
      })
    '';
  })

  ++ (with vimPlugins; [
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
