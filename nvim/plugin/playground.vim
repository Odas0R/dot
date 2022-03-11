augroup Playground
  au!
  " bash
  au FileType sh xnoremap <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <leader>rp vapyPgv:!bash<CR>

  " sql
  au FileType sql xnoremap <leader>r :DB<CR>
  au FileType sql nnoremap <leader>rp vap:DB<CR>
augroup end
