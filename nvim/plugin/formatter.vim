" Documentation: https://github.com/mhartington/formatter.nvim
"
autocmd FocusGained * checktime

augroup FormatAutogroup
  autocmd!

  " Formatter
  nnoremap <silent> gp <cmd>FormatWrite<cr>

  " ESLint
  autocmd BufWritePre *.tsx,*.ts,*.jsx,*.js EslintFixAll

augroup END
