" Documentation: nvim-toggle-terminal
"
" Press "K" on when cursor on top of telescope

nnoremap <silent> <leader>t <cmd>lua terminal:toggle()<cr>
tnoremap <silent> <leader>t <C-\><C-n><cmd>lua terminal:toggle()<cr>

tnoremap <expr> <Esc> (&filetype == "fzf") ? "<Esc>" : "<c-\><c-n>"
tnoremap <C-v><Esc> <Esc>

augroup terminal_settings
  autocmd!

	autocmd TermOpen * startinsert | setlocal nonumber norelativenumber
  autocmd TermLeave * stopinsert

  " Ignore various filetypes as those will close terminal automatically
  " Ignore fzf, ranger, coc
  autocmd TermClose *
        \ if (expand('<afile>') !~ "fzf") && (expand('<afile>') !~ "ranger") && (expand('<afile>') !~ "coc") |
        \   call nvim_input('<CR>')  |
        \ endif
augroup END

highlight! TermCursorNC guibg=red guifg=white ctermbg=1 ctermfg=15
