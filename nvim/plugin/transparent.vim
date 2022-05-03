augroup Transparent
  au!

  au VimEnter * highlight Normal guibg=NONE ctermbg=NONE
  au VimEnter * highlight CursorColumn cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight CursorLine cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight CursorLineNr cterm=NONE ctermbg=NONE ctermfg=NONE
  " au VimEnter * highlight SignColumn ctermbg=NONE cterm=NONE guibg=NONE gui=NONE

  " Signify Transparent Color
  au VimEnter * highlight SignifySignAdd    ctermfg=green  guifg=#00ff00 guibg=NONE ctermbg=NONE cterm=NONE gui=NONE
  au VimEnter * highlight SignifySignDelete ctermfg=red    guifg=#ff0000 guibg=NONE ctermbg=NONE cterm=NONE gui=NONE
  au VimEnter * highlight SignifySignChange ctermfg=yellow guifg=#ffff00 guibg=NONE ctermbg=NONE cterm=NONE gui=NONE
augroup end
