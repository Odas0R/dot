" Documentation: vim-markdown
"
" Press "K" on when cursor on top of vim-markdown

let g:netrw_browsex_viewer = "open"

let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal_code_blocks = 1
let g:vim_markdown_new_list_item_indent = 2

let g:vim_markdown_no_extensions_in_markdown = 0

let g:vim_markdown_autowrite = 1
let g:vim_markdown_edit_url_in = 'current'

" Experiments
let g:vim_markdown_conceal = 2

" Treesitter uses a differnt highlight group regarding markdown, etc:  
"
" TSTitle, TSLiteral, TSEmphasis, TSStrong, TSURI, TSTextReference,
" TSPunctSpecial and TSStringEscape.
"
highlight TSStrong guifg=#fabd2f gui=bold
highlight TSEmphasis guifg=#d3869b gui=italic

" 
" Markdown Custom Settings
" 
augroup markdown_custom_settings
  autocmd!
  autocmd FileType markdown setlocal
        \ conceallevel=2
        \ spell nonumber norelativenumber
        \ tw=80 foldlevel=99
        \ wrap linebreak
augroup END

" 
" Remmember Folding
" 
let g:markdown_folding = 1

augroup remember_folds
  autocmd!
  autocmd BufWinLeave *.md mkview
  autocmd BufWinEnter *.md silent! loadview
augroup END
