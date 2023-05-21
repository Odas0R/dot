vim.cmd([[
augroup Playground
  au!
  " bash
  au FileType sh xnoremap <buffer> <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <buffer> <leader>rp vapyPgv:!bash<CR>

  " sql
  au FileType sql,mysql xnoremap <buffer> <leader>r :DB<CR>
  au FileType sql,mysql nnoremap <buffer> <leader>rp vap:DB<CR>
augroup end
]])
