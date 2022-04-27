nnoremap <leader>zq <cmd>lua require("odas0r.telescope").search_zet({})<CR>
nnoremap <leader>zf <cmd>!zet fix %<CR>

" add files to the history of zettelkasten
augroup zettelkasten_history
  au!

  " add to history
  au BufWinEnter ~/github.com/odas0r/zet/fleet/*.md silent !zet history.insert %
  au BufWinEnter ~/github.com/odas0r/zet/permanent/*.md silent !zet history.insert %
augroup end
