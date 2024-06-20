{
  programs.neovim.extraConfig = /* vim */ ''
    " ########## GENERAL SETTINGS ##########
    set number
    set relativenumber
    set cursorline
    set cmdheight=2
    set scrolloff=3

    set notimeout
    set updatetime=1000

    set splitbelow

    "set completeopt=longest,menuone
    set wildmode=longest,full

    set undofile
    set backupdir-=.

    set expandtab
    set tabstop=4
    set shiftwidth=0 " use tabstop value

    augroup insert_mode_relativenumber
      au!
      au InsertEnter * set norelativenumber
      au InsertLeave * set relativenumber
    augroup

    " ########## MAPPINGS ##########
    map <silent> <expr> <F5> ':wa \| !' . g:build_cmd . '<CR>'

    " Move to the next buffer
    nmap <silent> <C-l> <Cmd>bnext<CR>
    tmap <silent> <C-l> <Cmd>bnext<CR>
    " Move to the previous buffer
    nmap <silent> <C-h> <Cmd>bprevious<CR>
    tmap <silent> <C-h> <Cmd>bprevious<CR>
    " quit current buffer and move to previous
    nmap <silent> <C-q> <Cmd>BClose<CR>
    tmap <silent> <C-q> <Cmd>BClose<CR>

    function! s:BClose()
      if(&modified)
        let answer = confirm("This buffer has been modified. Are you sure you want to delete it?", "&Yes\n&No", 2)
        if(answer != 1)
          return
        endif
      endif
      " if(!buflisted(winbufnr(0)))
      "   bd!
      "   return
      " endif
      let currentWindow = winnr()
      let currentBuffer = bufnr("%")
      keepjumps windo call s:GotoLastListedBuffer(currentBuffer)
      execute "bdelete!".currentBuffer
      execute "keepjumps ".currentWindow."wincmd w"
    endfunction
    function! s:GotoLastListedBuffer(bufferToBeDeleted)
      if bufnr("%") == a:bufferToBeDeleted
        if buflisted(bufnr("#"))
          buffer #
          return
        endif
        let [jumplist, currentIndex] = getjumplist()
        let jumplist = jumplist[:currentIndex - 1]
        call reverse(jumplist)
        for jump in jumplist
          if jump['bufnr'] != a:bufferToBeDeleted && buflisted(jump['bufnr'])
            execute "buffer!" jump['bufnr']
            return
          endif
        endfor
        " reached the start of the jumplist without finding a suitable
        " buffer so start Startify
        Startify
      endif
    endfunction

    command! BClose call s:BClose()

    nmap <C-S> <Cmd>w<CR>
    nmap <C-f> za
    imap <C-z> <C-o>zz

    nmap <C-Tab> <Cmd>set et! et?<CR>

    imap <C-h> <Left>
    imap <C-j> <Down>
    imap <C-k> <Up>
    imap <C-l> <Right>

    nnoremap <silent> # <Cmd>noh<CR>

    " ########## TERMINAL-RELATED MAPPINGS #########

    augroup terminal_mode
      au!
      au BufLeave * call s:SaveTerminalMode()
      au BufEnter * call s:LoadTerminalMode()
      " seems BufEnter doesn't activate on the initial opening?? or smthn
      au TermOpen * call s:LoadTerminalMode()
    augroup END

    function! s:SaveTerminalMode()
      if &buftype == "terminal"
        let b:terminal_mode = mode()
      endif
    endfunction
    function! s:LoadTerminalMode()
      if &buftype == "terminal"
        if !exists('b:terminal_mode')
          let b:terminal_mode = "t"
        endif
        if b:terminal_mode == "t"
          startinsert
        elseif b:terminal_mode == "n"
          stopinsert
        endif
      endif
    endfunction

    nmap <C-t> <Cmd>term bash<CR>
    tmap <C-t> <Cmd>term bash<CR>

    " ########## COMMAND ABBREVS ##########
    cabbr <expr> %% expand('%:p:h')
    cabbr wso w \| so %
    " cabbr .. e %:p:h
    cabbr S Startify
    cabbr \|S \| Startify
    cabbr qh windo if &ft == 'help' \| q \| endif
    cabbr qha tabdo windo if &ft == 'help' \| q \| endif
    " cabbr B let g:build_cmd = input("build_command: ")

    " ########## COMMANDS ##########
    command! -nargs=? BuildCmd if len(<q-args>) | let g:build_cmd = <q-args> | else | let g:build_cmd = input("build command: ") | endif

    command! RemoveTrailingWhitespace %s/\s\+$//e

    " ########## FOLDING ##########
    set foldmethod=expr
    set foldexpr=nvim_treesitter#foldexpr()
    set foldminlines=3
    set foldcolumn=auto:3
    set fillchars+=foldopen:,foldclose:

    function! s:Foldtext()
      let start = getline(v:foldstart)
      " for tabbed stuff
      " let start = substitute(start, '\\t', repeat('\ ', &tabstop), 'g')
      let end = trim(getline(v:foldend))
      return start . ' ... ' . end
    endfunction
    set foldtext=s:Foldtext()

    augroup filetypefolding
      au!
      au FileType nix setlocal foldlevel=99
    augroup END

    " ########## OTHER STUFF ##########

    function s:DetectNixShebang()
      if did_filetype()
        return
      endif
      if getline(1) !~# '\v^#!\s*\S*/bin/env\s+nix\s*$'
        return
      endif

      let fullcommand = "nix"
      let linenum = 2
      while 1
        let nextargs = matchstr(getline(linenum), '\v(^#!\s*nix\s*)@<=\S.*$')
        if empty(nextargs)
          break
        endif
        let fullcommand = fullcommand . ' ' . nextargs
        let linenum = linenum + 1
      endwhile

      function! Getfirstsubmatchor(str, m, default = ''')
        let list = a:str->matchlist(a:m)
        if empty(list)
          return a:default
        else
          return list[1]
        endif
      endfunction
      let trymatchtypes = [
      \	{str -> str->match('\v^nix\s+run\s+') == -1 ? ''' : Getfirstsubmatchor(str, '\v\s%([^#]&\S)*#(\S*)%(\s|$)') },
      \	{str -> str->match('\v^nix\s+shell\s+') == -1 ? ''' : Getfirstsubmatchor(str, '\v%(-c|--command)\s+(\S*)%(\s|$)', $SHELL) },
      \]

      let interpreter = v:null
      for Trymatchtype in trymatchtypes
        let possiblematch = Trymatchtype(fullcommand)
        if !empty(possiblematch)
          let interpreter = possiblematch
          break
        endif
      endfor

      if interpreter == v:null
        return
      endif

      let fullshebang = (interpreter->match('/') == -1 ? '#!/bin/env ' : '#!') . interpreter
      " would prefer to be able to directly call
      " dist#script#DetectFromHashBang(fullshebang)
      " to avoid all this malarky but oh well
      let currentbuffer = bufnr('%')
      exec "e " . tempname()
      let tempbuffer = bufnr('%')
      call append(0, fullshebang)
      call dist#script#DetectFiletype()
      let acfiletype = &ft
      exec "buffer! " . currentbuffer
      exec "bwipeout! " . tempbuffer
      let &ft = acfiletype
    endfunction

    augroup nixshebangfiletype
      au!
      au BufNewFile,BufRead * call s:DetectNixShebang()
    augroup END

    " just to limit the size of the terminal buffer name
    " set shell=bash
    " let $SHELL = 'bash'

    augroup commentstrings
      au!
      au FileType rust let &l:commentstring = '// %s'
      au FileType vim  let &l:commentstring = '" %s'
    augroup END

    augroup highlight_yank
      au!
      au TextYankPost * silent! lua vim.highlight.on_yank {higroup="YankRegion", timeout=400}
    augroup END

    " ########## COLOURSCHEMES ##########
    augroup colourschemes
      au!
      au ColorScheme * call s:Colourscheme(expand("<amatch>"))
    augroup END
    function! s:Colourscheme(name)
      " TODO: mebe add tui colours

      hi QuickScopePrimary gui=inverse
      hi QuickScopeSecondary gui=underline
      hi YankRegion guibg=yellow4
    endfunction

    lua << EOF
      local colors = require('ayu.colors')
      colors.generate()

      require("ayu").setup({
        overrides = {
          Normal = { bg = colors.black },
          LineNr = { fg = colors.comment },
          FoldColumn = { bg = colors.black },
          -- QuickScopePrimary = { bg = colors.selection_inactive },
        },
      })
    EOF

    " rewrite
    " colorscheme actually set by neovim-ayu config
    " so that it's config can be set before it is activated

    colorscheme ayu-dark
    " colorscheme github_dark_dimmed
    " colorscheme monokai-nightasty

    " ########## GUI ##########
    if has('gui_running')
      " generally assume gui is neovide
      let g:neovide_text_gamma = 0.8 "default: 0.0
      let g:neovide_text_contrast = 0.5 "default: 0.5

      set guifont=RobotoMono\ Nerd\ Font\ Mono:h10.5
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
