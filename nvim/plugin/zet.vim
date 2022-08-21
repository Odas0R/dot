
" add files to the history of zettelkasten
augroup zettelkasten_history
  au!

  " add to history
  au BufWinEnter ~/github.com/odas0r/zet/fleet/*.md silent !zet history insert %
  au BufWinEnter ~/github.com/odas0r/zet/permanent/*.md silent !zet history insert %

  " fix zettel on write
  au BufWritePost ~/github.com/odas0r/zet/fleet/*.md silent !zet repair %
  au BufWritePost ~/github.com/odas0r/zet/permanent/*.md silent !zet repair %

  " disable signify on zet
  au BufEnter ~/github.com/odas0r/zet/fleet/*.md SignifyDisable
  au BufEnter ~/github.com/odas0r/zet/permanent/*.md SignifyDisable
  au BufEnter ~/github.com/odas0r/zet/journal/*.md SignifyDisable

  " ------------------------------------
  " Testing purposes
  " ------------------------------------

  " add to history
  au BufWinEnter /tmp/foo/fleet/*.md silent !zet history insert %
  au BufWinEnter /tmp/foo/permanent/*.md silent !zet history insert %

  " fix zettel on write
  au BufWritePost /tmp/foo/fleet/*.md silent !zet repair %
  au BufWritePost /tmp/foo/permanent/*.md silent !zet repair %

  " disable signify on zet
  au BufEnter /tmp/foo/fleet/*.md SignifyDisable
  au BufEnter /tmp/foo/permanent/*.md SignifyDisable
  au BufEnter /tmp/foo/journal/*.md SignifyDisable
augroup end
