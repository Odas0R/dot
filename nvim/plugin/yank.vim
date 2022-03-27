" Docs: https://github.com/ojroques/vim-oscyank#copying-from-a-register

" > For the impatient one, copy this line to your config. Content will be
" > copied to clipboard after any yank operation:

" on yank copy to clipboard
set clipboard+=unnamedplus

let g:oscyank_max_length = 1000000

let g:oscyank_term = 'default'

let g:clipboard = {
        \   'name': 'osc53',
        \   'copy': {'+': {lines, regtype -> OSCYankString(join(lines, "\n"))}},
        \   'paste': {'+': {-> [split(getreg(''), '\n'), getregtype('')]}},
        \ }
