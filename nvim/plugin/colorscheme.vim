" Documentation: tokyonight
"
" Press "K" on when cursor on top of defx

let g:tokyonight_style = "night"
let g:tokyonight_italic_functions = 1
let g:tokyonight_transparent = 1
colorscheme tokyonight

" change themes
nnoremap <leader>8 :let g:tokyonight_style = "night"<cr>:colorscheme default<cr>:colorscheme tokyonight<cr>
nnoremap <leader>9 :let g:tokyonight_style = "day"<cr>:colorscheme default<cr>:colorscheme tokyonight<cr>
