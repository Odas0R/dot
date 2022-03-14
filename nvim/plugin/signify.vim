" Documentation: signify
"
" Press "K" on when cursor on top of signify

let g:signify_disable_by_default = 0

" https://github.com/mhinz/vim-signify/blob/master/doc/signify.txt#L597
highlight SignifySignAdd    ctermfg=green  guifg=#00ff00 cterm=NONE gui=NONE
highlight SignifySignDelete ctermfg=red    guifg=#ff0000 cterm=NONE gui=NONE
highlight SignifySignChange ctermfg=yellow guifg=#ffff00 cterm=NONE gui=NONE

" https://github.com/mhinz/vim-signify/blob/master/doc/signify.txt#L611
highlight SignColumn ctermbg=NONE cterm=NONE guibg=NONE gui=NONE

" hunk mappings
nnoremap <silent> <leader>gj <plug>(signify-next-hunk):SignifyHunkDiff<CR>
nnoremap <silent> <leader>gk <plug>(signify-prev-hunk):SignifyHunkDiff<CR>
nnoremap <silent> <leader>gd <cmd>SignifyHunkDiff<CR>

" hunk manipulations
nnoremap <silent> <leader>gu <cmd>SignifyHunkUndo<cr>
nnoremap <silent> <leader>gt <cmd>SignifyToggle<cr>

" When you jump to a hunk, show "[Hunk 2/15]" by putting this in your vimrc:
autocmd User SignifyHunk call s:show_current_hunk()

function! s:show_current_hunk() abort
  let h = sy#util#get_hunk_stats()
  if !empty(h)
    echo printf('[Hunk %d/%d]', h.current_hunk, h.total_hunks)
  endif
endfunction

