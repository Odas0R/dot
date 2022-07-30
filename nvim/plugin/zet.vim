nnoremap <leader>zq <cmd>lua require("odas0r.telescope").search_zet({})<CR>
nnoremap <leader>zf <cmd>!zet fix %<CR>

" add files to the history of zettelkasten
augroup zettelkasten_history
  au!

  " add to history
  au BufReadPre ~/github.com/odas0r/zet/fleet/*.md silent !zet history.insert %
  au BufReadPre ~/github.com/odas0r/zet/permanent/*.md silent !zet history.insert %

  " fix zettel on write
  au BufWritePost ~/github.com/odas0r/zet/fleet/*.md silent !zet fix %
  au BufWritePost ~/github.com/odas0r/zet/permanent/*.md silent !zet fix %

  " disable signify on zet
  au BufEnter ~/github.com/odas0r/zet/fleet/*.md SignifyDisable
  au BufEnter ~/github.com/odas0r/zet/permanent/*.md SignifyDisable
  au BufEnter ~/github.com/odas0r/zet/journal/*.md SignifyDisable
augroup end
