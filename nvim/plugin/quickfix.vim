" Documentation: quickfix
"
" Press "K" on when cursor on top of quickfix

" close quickfix-panel
map <silent> <leader>q <cmd>cclose<CR>
map <silent> <leader>o <cmd>copen<CR>

" move through the quickfix panel issues
nnoremap <silent> <C-j> :cnext<CR>
nnoremap <silent> <C-k> :cprev<CR>
