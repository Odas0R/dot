" Documentation: https://github.com/mhartington/formatter.nvim
"
autocmd FocusGained * checktime

augroup FormatAutogroup
  autocmd!

  " Formatter
  nnoremap <silent> gp <cmd>FormatWrite<cr>

  " auto fix
  autocmd BufWritePre *.ts,*.tsx,*.js,*.jsx EslintFixAll
augroup END
