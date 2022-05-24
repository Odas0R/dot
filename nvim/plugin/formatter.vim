" Documentation: https://github.com/mhartington/formatter.nvim
"
autocmd FocusGained * checktime

augroup FormatAutogroup
  autocmd!

  " Formatter
  nnoremap <silent> gp <cmd>FormatWrite<cr>

  function TSFix()
    :TSLspImportAll
    :EslintFixAll
  endfunction

  " ESLint
  autocmd BufWritePre *.tsx,*.ts,*.jsx,*.js call TSFix()

augroup END
