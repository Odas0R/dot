" Documentation: telescope
"
" Press "K" on when cursor on top of telescope

lua require("odas0r")

nnoremap <silent> <C-p> <cmd>Telescope git_files<cr>
nnoremap <silent> <C-g> <cmd>Telescope live_grep<cr>
nnoremap <silent> <leader>b <cmd>Telescope buffers<cr>

" custom telescope built-ins
nnoremap <leader>ve <cmd>lua require("odas0r.telescope").search_dotfiles()<CR>
