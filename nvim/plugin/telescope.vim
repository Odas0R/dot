lua require("odas0r")

nnoremap <leader>ve :lua require("odas0r.telescope").search_dotfiles()<CR>

" telescope
nnoremap <silent> <C-p> <cmd>Telescope git_files<cr>
nnoremap <silent> <C-g> <cmd>Telescope live_grep<cr>
nnoremap <silent> <leader>b <cmd>Telescope buffers<cr>
nnoremap <silent> <leader>d <cmd>Telescope diagnostics<cr>
