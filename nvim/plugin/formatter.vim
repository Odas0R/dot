" Documentation: https://github.com/mhartington/formatter.nvim
"
autocmd FocusGained * checktime

function! FixImports()
  :TypescriptAddMissingImports!
  :TypescriptOrganizeImports!
endfunction

augroup FormatAutogroup
  autocmd!

  " Formatter
  nnoremap <silent> gp <cmd>FormatWrite<cr>

  " auto fix
  autocmd BufWritePre *.ts,*.tsx,*.js,*.jsx EslintFixAll
augroup END
