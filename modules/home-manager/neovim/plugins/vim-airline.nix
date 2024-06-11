{
  config = /* vim */ ''
    call airline#parts#define_accent('linenr', 'none')
    call airline#parts#define_accent('maxlinenr', 'none')
    let g:airline_section_z = airline#section#create(['windowswap', 'obsession', '%p%%', 'linenr', 'maxlinenr', 'colnr'])
  '';

  gui-config = /* vim */ ''
    let g:airline_powerline_fonts = 1

    if !exists('g:airline_symbols')
        let g:airline_symbols = {}
    endif

    let g:airline_symbols = {
        \'linenr': ' :',
        \'modified': '+',
        \'whitespace': '☲',
        \'branch': '',
        \'ellipsis': '...',
        \'paste': 'PASTE',
        \'maxlinenr': '☰ ',
        \'readonly': '',
        \'spell': 'SPELL',
        \'space': ' ',
        \'dirty': '⚡',
        \'colnr': ' :',
        \'keymap': 'Keymap:',
        \'crypt': '🔒',
        \'notexists': 'Ɇ'
        \}
    let g:airline_left_sep = ''
    let g:airline_left_alt_sep = ''
    let g:airline_right_sep = ''
    let g:airline_right_alt_sep = ''
  '';
}
