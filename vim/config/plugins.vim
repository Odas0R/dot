call plug#begin('~/.vim/plugged')

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'z0mbix/vim-shfmt', { 'for': 'sh' }
Plug 'mattn/emmet-vim'
Plug 'yuezk/vim-js'
Plug 'HerringtonDarkholme/yats.vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'morhetz/gruvbox'
Plug 'ghifarit53/tokyonight-vim'
Plug 'itchyny/lightline.vim'
Plug 'Shougo/vimfiler.vim'
Plug 'Shougo/unite.vim'
Plug 'tpope/vim-eunuch' " Commands to Move, Rename, Delete files
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'Raimondi/delimitMate'
Plug 'plasticboy/vim-markdown'
Plug 'junegunn/goyo.vim'
Plug 'vitalk/vim-simple-todo' " TODO: Create your own plugin

call plug#end()

" theme
"
" https://github.com/morhetz/gruvbox
"
colorscheme gruvbox
let g:gruvbox_contrast_dark = 'hard'
let g:gruvbox_italic=1

" lightline
"
" https://github.com/itchyny/lightline.vim
"
let g:lightline = {
      \ 'colorscheme': 'gruvbox',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch' ],
      \             [ 'readonly', 'filename', 'modified' ] ],
      \ }
      \ }

" Emmet
"
" https://github.com/mattn/emmet-vim
"
let g:user_emmet_expandabbr_key='<leader><tab>'
imap <expr> <leader><tab> emmet#expandAbbrIntelligent("\<leader><tab>")

" shfmt - bash formatter
"
" https://github.com/mvdan/sh
"
let g:shfmt_fmt_on_save = 1

" shfmt uses tabs by default, use spaces instead
"
" Yaml, Dockerfiles, etc, all use spaces so it's better
" to keep this format
let g:shfmt_extra_args = '-i 2'

" Golang
"
" https://github.com/fatih/vim-go
"
let g:go_fmt_fail_silently = 0
let g:go_fmt_command = 'goimports'
let g:go_fmt_autosave = 1
let g:go_gopls_enabled = 1
let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_operators = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_variable_declarations = 1
let g:go_highlight_variable_assignments = 1
let g:go_highlight_build_constraints = 1
let g:go_highlight_diagnostic_errors = 1
let g:go_highlight_diagnostic_warnings = 1
let g:go_auto_type_info = 1
let g:go_auto_sameids = 0
"let g:go_metalinter_command='golangci-lint'
let g:go_metalinter_command='golint'
let g:go_metalinter_autosave=1
"let g:go_gopls_analyses = { 'composites' : v:false }
au FileType go nmap <leader>t :GoTest!<CR>
au FileType go nmap <leader>v :GoVet!<CR>
au FileType go nmap <leader>b :GoBuild!<CR>
au FileType go nmap <leader>c :GoCoverageToggle<CR>
au FileType go nmap <leader>i :GoInfo<CR>
au FileType go nmap <leader>l :GoMetaLinter!<CR>

" Vim Markdown
"
" https://github.com/plasticboy/vim-markdown
"
" Useful Tips:
" - Use :Goyo to read your notes
"

" open links even in non.md files
let g:vim_markdown_no_extensions_in_markdown = 1
let g:vim_markdown_autowrite = 1

" remove markdown folding
let g:vim_markdown_folding_disabled = 1

" add conceallevel 2 on markdown files
au FileType markdown setlocal conceallevel=2

" auto format on file save
au FileType markdown nnoremap <leader>f gggqG :w<cr>
au FileType markdown inoremap <leader>f <esc> gggqG :w<cr>

" remove new list indetation"
let g:vim_markdown_new_list_item_indent = 0

" open a new .md file on the current view
let g:vim_markdown_edit_url_in = 'current'

" open the link on the default browser
let g:netrw_browsex_viewer="cmd.exe /C start"

" Use `<C-k>` and `<C-j>` to navigate headers
autocmd FileType markdown augroup vimrc
au VimEnter * unmap <C-j>
au VimEnter * nmap <C-k> <Plug>Markdown_MoveToPreviousHeader
au VimEnter * nmap <C-j> <Plug>Markdown_MoveToNextHeader
augroup END

" Coc Configuration
"
" Use `<C-k>` and `<C-j>` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
"
" https://github.com/neoclide/coc.nvim/wiki/Language-servers
"
nmap <silent> <C-k> <Plug>(coc-diagnostic-prev)
nmap <silent> <C-j> <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
      \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>
function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" VimFiler
"
" https://github.com/Shougo/vimfiler.vim/blob/master/doc/vimfiler.txt
"
let g:vimfiler_as_default_explorer = 1
let g:vimfiler_enable_auto_cd = 1

au FileType vimfiler inoremap <C-h> <C-w>h
au FileType vimfiler inoremap <C-l> <C-l>l

" open vimfiler when there's no file args
autocmd VimEnter * if !argc() | VimFiler | endif

" Toggle VimFiler with '\'
nnoremap \ :VimFilerExplorer<CR>
autocmd FileType vimfiler nmap <buffer> \ <Plug>(vimfiler_close)

" FZF
"
" https://github.com/junegunn/fzf.vim
"
let g:fzf_preview_window = ['right:60%:wrap', 'ctrl-/']

" command to show fzf
nnoremap <C-p> :Files<cr>

" preview window
command! -bang -nargs=? -complete=dir Files
      \ call fzf#vim#files(
      \ <q-args>,
      \ fzf#vim#with_preview(
      \   {'options': ['--layout=reverse', '--info=inline']}
      \ ), <bang>1)
