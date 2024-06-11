{
  programs.neovim.extraConfig = /* vim */ ''
    augroup highlight_yank
      au!
      au TextYankPost * silent! lua vim.highlight.on_yank {higroup="YankRegion", timeout=400}
    augroup END

    "TODO: add tui colours
    hi YankRegion guibg=yellow4
    hi QuickScopePrimary gui=underline gui=standout
    hi QuickScopeSecondary gui=underline
    hi YankRegion guibg=yellow4

    if has('gui_running')
      set guifont=RobotoMono\ Nerd\ Font\ Mono\ Lt:h10
      set guicursor=
          \a:Cursor,
          \n-v:block,
          \c-ci-i:ver25,
          \r-cr:hor20,
          \a:blinkon0,
          \o:blinkwait1-blinkoff150-blinkon175,

      let g:terminal_color_4 = '#4040ff'
      let g:terminal_color_12 = '#8080ff'

      " hi Normal ctermfg=white guifg=white  guibg=black

      hi Pmenu guibg=#292929
      hi PmenuSel guibg=gray
      hi SignColumns guibg=black

      hi TabLineFill guifg=#000000 guibg=#000000
      hi TabLine gui=NONE
      hi Folded guibg=gray10
      hi FoldColumn guibg=gray10
      hi SignColumn guibg=gray15
      hi SpecialKey guifg='cyan4'
    endif
  '';
}
