" Documentation: telescope
"
" Press "K" on when cursor on top of telescope

nnoremap <silent> <C-p> <cmd>Telescope find_files<cr>
nnoremap <silent> <C-g> <cmd>Telescope live_grep<cr>

nnoremap <silent> <leader>fe <cmd>lua require("odas0r.telescope").search_repos()<cr>
nnoremap <silent> <leader>fg <cmd>lua require("odas0r.telescope").search_repos_grep()<cr>
