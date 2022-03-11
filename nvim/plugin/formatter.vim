" Documentation: https://github.com/mhartington/formatter.nvim

augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
