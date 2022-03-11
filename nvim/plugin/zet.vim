nnoremap <leader>zf <cmd>lua require("odas0r.telescope").search_zet_fleet()<CR>
nnoremap <leader>zp <cmd>lua require("odas0r.telescope").search_zet_permanent()<CR>

" add files to the history of zettelkasten
augroup zettelkasten_history
  au!
  " add to history
  au BufWinEnter ~/github.com/zet-cmd/.zet/**/*.md silent !zet history.insert %
  au BufWinEnter ~/github.com/zet/fleet/*.md silent !zet history.insert %
  au BufWinEnter ~/github.com/zet/permanent/*.md silent !zet history.insert %
augroup end
