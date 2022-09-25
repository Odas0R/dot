" Documentation: telescope
"
" Press "K" on when cursor on top of telescope

nnoremap <silent> <C-p> <cmd>Telescope find_files<cr>
nnoremap <silent> <C-g> <cmd>Telescope live_grep<cr>
nnoremap <silent> <Leader>ve <cmd>lua require("odas0r.telescope").search_dotfiles()<cr>
nnoremap <silent> <Leader>vg <cmd>lua require("odas0r.telescope").search_dotfiles_grep()<cr>
