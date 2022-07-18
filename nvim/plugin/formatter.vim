" Documentation: https://github.com/mhartington/formatter.nvim
"
autocmd FocusGained * checktime

function! CustomFormatJS()
  :TypescriptAddMissingImports!
  :TypescriptOrganizeImports!
  :EslintFixAll
endfunction

augroup FormatAutogroup
  autocmd!
  " Formatter
  nnoremap <silent> gp <cmd>FormatWrite<cr>
  " ESLint
  autocmd BufWrite *.tsx,*.ts,*.jsx,*.js call CustomFormatJS()<CR>

augroup END
