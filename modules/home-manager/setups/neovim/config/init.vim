" ########## GENERAL SETTINGS ##########
set number
set relativenumber
set cursorline
set cmdheight=2
set scrolloff=3

set notimeout
set updatetime=1000

set splitbelow

set completeopt=longest,menuone,preview
set wildmode=longest,full
set winborder=rounded

set undofile
set backupdir-=.

augroup noundo
  au!
  au BufWritePre /tmp/* setlocal noundofile
augroup END

set expandtab
set tabstop=4
set shiftwidth=0 " use tabstop value
set nofixeol

set conceallevel=2

augroup insert_mode_relativenumber
  au!
  au InsertEnter * if &buftype == "" | set norelativenumber | endif
  au InsertLeave * if &buftype == "" | set relativenumber | endif
augroup END

" ########## MAPPINGS ##########
map <silent> <expr> <F5> ':wa \| term ' . g:build_cmd . '<CR>'
map <silent> <expr> <F6> ':wa \| !' . g:build_cmd . '<CR>'

nmap <C-S> <Cmd>update<CR>
nmap <C-f> za
imap <C-z> <C-o>zz

nmap <C-Tab> <Cmd>set et! et?<CR>

imap <C-h> <Left>
imap <C-j> <Down>
imap <C-k> <Up>
imap <C-l> <Right>

nnoremap <silent> # <Cmd>noh<CR>

noremap <expr> <C-\><C-V> nr2char(getchar())
" insert mode already has <C-V> but for symmetry :)
inoremap <expr> <C-\><C-V> nr2char(getchar())
tnoremap <expr> <C-\><C-V> nr2char(getchar())

" ########## DIAGNOSTICS #########

map gdd <Cmd>lua vim.diagnostic.open_float()<CR>
map gdo <Cmd>lua vim.diagnostic.setqflist()<CR>

lua <<EOF
  local virtual_lines = false

  vim.diagnostic.config({
    severity_sort = true,
    virtual_text = function() return not virtual_lines end,
    virtual_lines = function() return virtual_lines end,
    jump = {
      float = true,
    },
  })

  vim.keymap.set('n', 'gdv', function()
    virtual_lines = not virtual_lines
    -- refresh diagnostics
    vim.diagnostic.show()
  end)
EOF

" ########## LSP STUFF #########

" inoremap <expr> <Tab> SmartTab()

function! SmartTab()
  if match(strpart(getline('.'), 0, col('.') - 1), "^\\s*$") == -1
    return "\<C-X>\<C-O>"
  else
    return "\<Tab>"
  endif
endfunction

map grd <Cmd>lua vim.lsp.buf.definition()<CR>
map grI <Cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>

lua <<EOF
  vim.api.nvim_create_augroup('lsp_stuff', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = 'lsp_stuff',
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)

      if client.supports_method('textDocument/documentHighlight') then
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = args.buf,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd('CursorMoved', {
          buffer = args.buf,
          callback = vim.lsp.buf.clear_references,
        })
      end

      if client.supports_method('textDocument/inlayHint') then
        vim.lsp.inlay_hint.enable(true)
      end

      -- copied from neovim docs (:help lsp-format)
      if not client:supports_method('textDocument/willSaveWaitUntil')
          and client:supports_method('textDocument/formatting') then
        vim.api.nvim_create_autocmd('BufWritePre', {
          -- group = vim.api.nvim_create_augroup('my.lsp', {clear=false}),
          buffer = args.buf,
          callback = function()
            vim.lsp.buf.format({ bufnr = args.buf, id = client.id, timeout_ms = 1000 })
          end,
        })
      end
    end,
  })
EOF

" ########## BUFFER/WINDOW MOVEMENT/MANIPULATION #########

augroup save_load_mode
  au!
  au BufLeave * call s:SaveMode()
  au BufEnter * call s:LoadMode(&buftype)
  au TermOpen * call s:LoadMode('terminal')

  au SessionLoadPost * call s:LoadMode(&buftype, v:true)
augroup END

function! s:SaveMode()
  " if a session is loading, don't save the mode
  " (bc every buffer is being opened at once)
  if exists('g:SessionLoad') && g:SessionLoad == 1
    return
  endif

  if exists('b:ignore_next_mode') && b:ignore_next_mode
    let b:ignore_next_mode = v:false
    return
  endif

  let b:terminal_checked = v:true
  let b:buffer_mode = mode()
endfunction
function! s:LoadMode(loadtype = '', isSessionLoadPost = v:false)
  " if a session is loading, don't load the mode unless the
  " session loading has finished and then only if it is the
  " last buffer being being called with the autocmd
  " (and thus it is the current buffer)
  if a:isSessionLoadPost
    if !exists('g:SessionLoadBufNum')
      let g:SessionLoadBufNum = 0
    endif
    let g:SessionLoadBufNum += 1
    if g:SessionLoadBufNum < len(getbufinfo({ 'bufloaded':1 }))
      return
    endif
    unlet g:SessionLoadBufNum
  elseif exists('g:SessionLoad') && g:SessionLoad == 1
    return
  endif

  " we don't know if an empty buffer is from :enew or :term
  " during the BufEnter autocmd, so we allow the default to
  " be set until we can confirm one way or the other
  if !exists('b:buffer_mode') || !exists('b:terminal_checked')
    if a:loadtype == 'terminal'
      let b:buffer_mode = "t"
      let b:terminal_checked = v:true
    else
      let b:buffer_mode = "n"
    endif
  endif
  if b:buffer_mode == mode()
    return
  endif

  if b:buffer_mode == "t"
    startinsert
  elseif b:buffer_mode == "i"
    exe "normal! \<C-\>\<C-N>`^"
    if col("'^") > len(getline("'^"))
      startinsert!
    else
      startinsert
    endif
  elseif b:buffer_mode == "n"
    if mode() == "t"
      stopinsert
    else
      exe "normal! \<C-\>\<C-N>"
    endif
  endif
endfunction

" ALT+hjkl to move windows
nmap <silent> <A-h> <C-W>h
nmap <silent> <A-j> <C-W>j
nmap <silent> <A-k> <C-W>k
nmap <silent> <A-l> <C-W>l
" multiple '<Cmd>..<CR>'s because insert mode can
" only fully stop after leaving the <Cmd> scope
imap <A-h> <Cmd>PrepareWindowMove h<CR><Cmd>wincmd h<CR>
imap <A-j> <Cmd>PrepareWindowMove j<CR><Cmd>wincmd j<CR>
imap <A-k> <Cmd>PrepareWindowMove k<CR><Cmd>wincmd k<CR>
imap <A-l> <Cmd>PrepareWindowMove l<CR><Cmd>wincmd l<CR>
tmap <A-h> <Cmd>PrepareWindowMove h<CR><Cmd>wincmd h<CR>
tmap <A-j> <Cmd>PrepareWindowMove j<CR><Cmd>wincmd j<CR>
tmap <A-k> <Cmd>PrepareWindowMove k<CR><Cmd>wincmd k<CR>
tmap <A-l> <Cmd>PrepareWindowMove l<CR><Cmd>wincmd l<CR>

command! -nargs=1 PrepareWindowMove call s:PrepareWindowMove("<args>")
function! s:PrepareWindowMove(direction)
  if winbufnr(winnr(a:direction)) ==# bufnr()
    " cursor would not actually move or it would move
    " to the same buffer so this would mess it up
    return
  endif

  call s:SaveMode()
  let b:ignore_next_mode = v:true
  stopinsert
endfunction

" Move to the next buffer
nmap <silent> <C-l> <Cmd>bnext<CR>
tmap <silent> <C-l> <Cmd>bnext<CR>
" Move to the previous buffer
nmap <silent> <C-h> <Cmd>bprevious<CR>
tmap <silent> <C-h> <Cmd>bprevious<CR>
" quit current buffer and move to previous
nmap <silent> <C-q> <Cmd>BClose<CR>
tmap <silent> <C-q> <Cmd>BClose<CR>

command! BClose call s:BClose()
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
  execute "bdelete!" currentBuffer
  execute "keepjumps" currentWindow "wincmd w"
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

" ########## TERMINAL-RELATED MAPPINGS #########
nmap <C-t> <Cmd>term bash<CR>
tmap <C-t> <Cmd>term bash<CR>

tnoremap <expr> <C-\><C-R> getreg(nr2char(getchar()))
tnoremap <Esc> <Cmd>TerminalEsc<CR>

command! TerminalEsc call s:TerminalEsc()
function! s:TerminalEsc()
  if buffer_name('%') =~ '^.*:bash$' 
    stopinsert
  else
    call feedkeys("\<Esc>", 'n')
  endif
endfunction

" a tad odd when switching buffers (enters insert mode in switched buffer) but eh
tmap <C-\>: <C-\><C-O>:

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
" as it turns out this was from the treesitter plugin and is broke
" set foldexpr=nvim_treesitter#foldexpr()
set foldexpr=v:lua.vim.treesitter.foldexpr()
set foldminlines=3
set foldcolumn=auto:3
set fillchars+=foldopen:,foldclose:

set foldtext=

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

  function! Getfirstsubmatchor(str, m, default = '')
    let list = a:str->matchlist(a:m)
    if empty(list)
      return a:default
    else
      return list[1]
    endif
  endfunction
  let trymatchtypes = [
  \	{str -> str->match('\v^nix\s+run\s+') == -1 ? '' : Getfirstsubmatchor(str, '\v\s%([^#]&\S)*#(\S*)%(\s|$)') },
  \	{str -> str->match('\v^nix\s+shell\s+') == -1 ? '' : Getfirstsubmatchor(str, '\v%(-c|--command)\s+(\S*)%(\s|$)', $SHELL) },
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

  let b:fullshebang = '#!' . interpreter
  lua <<EOF
    vim.print(vim.b.fullshebang)
    local ft, on_detect = vim.filetype.match({ contents = { vim.b.fullshebang } })
    if not ft then
      ft, on_detect = vim.filetype.match({ filename = vim.api.nvim_buf_get_name(0) })
    end

    if ft then vim.bo.ft = ft end
    if on_detect then on_detect(0) end
EOF
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

  hi Pmenu guibg=#292929
  hi PmenuSel guibg=gray
  hi! link NormalFloat Pmenu
  hi! link FloatBorder NormalFloat

  hi Folded guibg=gray10
  " hi FoldColumn guibg=gray10
  " hi SignColumn guibg=gray15
  hi SpecialKey guifg='cyan4'
endfunction

colorscheme ayu-dark
" colorscheme github_dark_dimmed
" colorscheme monokai-nightasty

" ########## GUI ##########

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
