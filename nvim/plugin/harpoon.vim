" Documentation: https://github.com/ThePrimeagen/harpoon

lua require("odas0r")

nnoremap <silent><leader><leader>a :lua require("harpoon.mark").add_file()<CR>
nnoremap <silent><C-e> :lua require("harpoon.ui").toggle_quick_menu()<CR>

nnoremap <silent> <leader>1 :lua require("harpoon.ui").nav_file(1)<CR>
tnoremap <silent> <leader>1 <C-\><C-n>:lua require("harpoon.ui").nav_file(1)<CR>

nnoremap <silent> <leader>1 :lua require("harpoon.ui").nav_file(1)<CR>
tnoremap <silent> <leader>1 <C-\><C-n>:lua require("harpoon.ui").nav_file(1)<CR>

nnoremap <silent> <leader>2 :lua require("harpoon.ui").nav_file(2)<CR>
tnoremap <silent> <leader>2 <C-\><C-n>:lua require("harpoon.ui").nav_file(2)<CR>

nnoremap <silent> <leader>3 :lua require("harpoon.ui").nav_file(3)<CR>
tnoremap <silent> <leader>3 <C-\><C-n>:lua require("harpoon.ui").nav_file(3)<CR>

nnoremap <silent> <leader>4 :lua require("harpoon.ui").nav_file(4)<CR>
tnoremap <silent> <leader>4 <C-\><C-n>:lua require("harpoon.ui").nav_file(4)<CR>
