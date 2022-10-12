augroup Transparent
  au!

  au VimEnter * highlight Normal guibg=NONE ctermbg=NONE
  au VimEnter * highlight ZenBg guibg=NONE ctermbg=NONE
  au VimEnter * highlight CursorColumn cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight CursorLine cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight CursorLineNr cterm=NONE ctermbg=NONE ctermfg=NONE
  au VimEnter * highlight SignColumn ctermbg=NONE guibg=NONE

  " Wierd fix on the highlight of harpoon ...
  au Filetype harpoon highlight HarpoonWindow cterm=NONE guibg=NONE ctermbg=NONE ctermfg=gray
  au Filetype harpoon highlight HarpoonBorder cterm=NONE guibg=NONE ctermbg=NONE ctermfg=gray
augroup end

