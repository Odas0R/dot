lua require("odas0r")

nnoremap <silent><leader>a :lua require("harpoon.mark").add_file()<CR>
nnoremap <silent><C-e> :lua require("harpoon.ui").toggle_quick_menu()<CR>

nnoremap <silent> <leader>q :lua require("harpoon.ui").nav_file(1)<CR>
nnoremap <silent> <leader>w :lua require("harpoon.ui").nav_file(2)<CR>
nnoremap <silent> <leader>e :lua require("harpoon.ui").nav_file(3)<CR>
nnoremap <silent> <leader>r :lua require("harpoon.ui").nav_file(4)<CR>
