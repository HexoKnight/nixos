pkgs:
{
  plugin = pkgs.vimPlugins.bufferline-nvim.overrideAttrs {
    postPatch = ''
      substituteInPlace lua/bufferline/ui.lua \
        --replace-fail \
        'local left_space, right_space = add_space(ctx, name_size)' \
        'local left_space, right_space = add_space(ctx, name_size)
          indicator.text = ""
        ' \
        --replace-fail \
        'local right_sep, left_sep = get_separator(focused, style)' \
        '
          local right_sep, left_sep
          if style == "airline" then
            if context.tab:current() then
              right_sep = "c"
            else
              right_sep = "u"
            end
          else
            right_sep, left_sep = get_separator(focused, style)
          end
        ' \
        --replace-fail \
        'return function(next_item)' \
        'return function(next_item)
          if right_separator.text == "c" or right_separator.text == "u" then
            local right = { text = "", highlight = right_separator.highlight }
            local is_last = next_item == nil

            if right_separator.text == "c" then
              right.text = ""
            elseif not is_last then
              if not next_item:current() then
                right.text = ""
              else
                right.text = ""
              end
            end

            if right.text ~= "" then table.insert(component, right) end
            return component
          end
        '
    '';
  };
  type = "lua";
  config = /* lua */ ''
    local selected_bg = {
      bg = { attribute = 'fg', highlight = 'Identifier', },
    }
    local selected = {
      italic = false, bold = false,
      fg = { attribute = 'bg', highlight = 'Normal', },
      bg = { attribute = 'fg', highlight = 'Identifier', },
    }
    require('bufferline').setup({
      options = {
        show_buffer_close_icons = false,
        -- only allowed due to patch
        separator_style = 'airline', --
        numbers = 'buffer_id',
      },
      highlights = {
        buffer_selected = selected,
        numbers_selected = selected,
        modified_selected = selected,
        duplicate_selected = selected,
                diagnostic_selected = selected_bg,
                      hint_selected = selected_bg,
           hint_diagnostic_selected = selected_bg,
                      info_selected = selected_bg,
           info_diagnostic_selected = selected_bg,
                   warning_selected = selected_bg,
        warning_diagnostic_selected = selected_bg,
                     error_selected = selected_bg,
          error_diagnostic_selected = selected_bg,

        separator = {
          fg = { attribute = 'fg', highlight = 'Identifier', },
          bg = { attribute = 'bg', highlight = 'Normal', },
        },
      },
    })
  '';
}
