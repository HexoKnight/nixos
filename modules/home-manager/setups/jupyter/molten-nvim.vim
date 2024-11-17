let g:molten_auto_open_output = v:false
let g:molten_wrap_output = v:true
let g:molten_virt_text_output = v:true
let g:molten_virt_lines_off_by_1 = v:true

let $JUPYTER_DATA_DIR = $XDG_RUNTIME_DIR . "/jupyter"
lua vim.system({'mkdir', '-p', vim.env.JUPYTER_DATA_DIR .. '/runtime'})

nmap <silent> <LocalLeader>me <Cmd>MoltenEvaluateOperator<CR>
nmap <silent> <LocalLeader><CR> <Cmd>MoltenEnterOutput<CR>

nmap <silent> <LocalLeader><CR> <Cmd>noautocmd MoltenEnterOutput<CR>

nmap <silent> <LocalLeader>k <Cmd>MoltenPrev<CR>
nmap <silent> <LocalLeader>j <Cmd>MoltenNext<CR>
