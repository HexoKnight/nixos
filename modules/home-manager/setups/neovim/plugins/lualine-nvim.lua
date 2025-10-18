-- https://github.com/nvim-lualine/lualine.nvim/wiki/Component-snippets
local function trailing_whitespace()
  local space = vim.fn.search([[\s\+$]], 'nwc')
  return space ~= 0 and "TW:"..space or ""
end
local function mixed_indent()
  local space_pat = [[\v^ +]]
  local tab_pat = [[\v^\t+]]
  local space_indent = vim.fn.search(space_pat, 'nwc')
  local tab_indent = vim.fn.search(tab_pat, 'nwc')
  local mixed = (space_indent > 0 and tab_indent > 0)
  local mixed_same_line
  if not mixed then
    mixed_same_line = vim.fn.search([[\v^(\t+ | +\t)]], 'nwc')
    mixed = mixed_same_line > 0
  end
  if not mixed then return '' end
  if mixed_same_line ~= nil and mixed_same_line > 0 then
     return 'MI:'..mixed_same_line
  end
  local space_indent_cnt = vim.fn.searchcount({pattern=space_pat, max_count=1e3}).total
  local tab_indent_cnt =  vim.fn.searchcount({pattern=tab_pat, max_count=1e3}).total
  if space_indent_cnt > tab_indent_cnt then
    return 'MI:'..tab_indent
  else
    return 'MI:'..space_indent
  end
end

require('lualine').setup({
  options = {
    theme = 'ayu',
  },
  sections = {
    lualine_x = {
      -- TODO: allow configuring this externally
      function()
        -- lualine ignores this component if it errors
        -- so no issue with it's unconditional inclusion
        return require('direnv').statusline()
      end,
      'encoding',
      'fileformat',
      'filetype',
    },
    lualine_z = {
      'location',
      trailing_whitespace,
      mixed_indent,
    },
  },
  -- tabline = {
  --   lualine_a = {
  --     {
  --       'buffers',
  --       show_filename_only = false,
  --       mode = 4,
  --       max_length = function() return vim.o.columns end,
  --       filetype_names = {
  --         startify = 'Startify',
  --       },
  --     }
  --   },
  -- },
})
