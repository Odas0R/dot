augroup Playground
  au!
  " bash
  au FileType sh xnoremap <buffer> <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <buffer> <leader>rp vapyPgv:!bash<CR>

  " sql
  au FileType sql xnoremap <buffer> <leader>r :DB<CR>
  au FileType sql nnoremap <buffer> <leader>rp vap:DB<CR>
augroup end
