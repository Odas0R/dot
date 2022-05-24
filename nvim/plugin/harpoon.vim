" Documentation: https://github.com/ThePrimeagen/harpoon

nnoremap <silent><leader><leader>a :lua require("harpoon.mark").add_file()<CR>
nnoremap <silent><C-e> :lua require("harpoon.ui").toggle_quick_menu()<CR>

nnoremap <silent> <leader>1 :lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(1)<CR>:cclose<CR>
tnoremap <silent> <leader>1 <C-\><C-n>:lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(1)<CR>

nnoremap <silent> <leader>2 :lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(2)<CR>:cclose<CR>
tnoremap <silent> <leader>2 <C-\><C-n>:lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(2)<CR>

nnoremap <silent> <leader>3 :lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(3)<CR>:cclose<CR>
tnoremap <silent> <leader>3 <C-\><C-n>:lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(3)<CR>

nnoremap <silent> <leader>4 :lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(4)<CR>:cclose<CR>
tnoremap <silent> <leader>4 <C-\><C-n>:lua terminal:close()<CR>:lua require("harpoon.ui").nav_file(4)<CR>

