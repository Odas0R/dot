" Documentation: telescope
"
" Press "K" on when cursor on top of telescope

nnoremap <silent> <C-p> <cmd>Telescope find_files<cr>
nnoremap <silent> <C-f> <cmd>Telescope grep_string<cr>
nnoremap <silent> <C-g> <cmd>Telescope live_grep<cr>

" custom telescope built-ins
nnoremap <leader>ve <cmd>lua require("odas0r.telescope").search_dotfiles()<CR>
