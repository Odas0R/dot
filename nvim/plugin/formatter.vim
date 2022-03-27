" Documentation: https://github.com/mhartington/formatter.nvim
"
autocmd FocusGained * checktime

augroup FormatAutogroup
  autocmd!
  nnoremap <silent> gp <cmd>FormatWrite<cr>
augroup END
