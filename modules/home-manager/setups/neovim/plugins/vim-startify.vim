let g:startify_session_persistence = 1
let g:startify_session_before_save = [
    \'silent! tabdo NERDTreeClose',
    \'silent! tabdo UndotreeHide',
    \]
let g:startify_change_to_vcs_root = 1
" let g:startify_bookmarks = [{'v': '~/.vimrc'}, {'g': '~/.gvimrc'}, {'~': '~'}]
" let g:startify_skiplist = ['doc\\.*\.txt$',]
let g:startify_session_autoload = 1
let g:startify_lists = [
    \{ 'type': 'sessions',  'header': ['   Sessions']       },
    \{ 'type': 'files',     'header': ['   MRU']            },
    \{ 'type': 'bookmarks', 'header': ['   Bookmarks']      },
    \{ 'type': 'commands',  'header': ['   Commands']       },
    \]
    " \ { 'type': 'dir',       'header': ['   MRU '. getcwd()] },
