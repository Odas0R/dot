augroup Transparent
  au!

  au VimEnter * highlight Normal guibg=NONE ctermbg=NONE
  au VimEnter * highlight ZenBg guibg=NONE ctermbg=NONE
  au VimEnter * highlight CursorColumn cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight CursorLine cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight CursorLineNr cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight SignColumn ctermbg=NONE guibg=NONE

augroup end
