set nocompatible
syntax on                                                         " syntax for plugins etc
filetype plugin on                                                " allow sensing the file type
set ttyfast                                                       " faster scrolling

set autowrite                                                     " automatically write files when changing when multiple files open
set relativenumber
set ruler                                                         " turn col and row position on in bottom right
set showmode                                                      " show command and insert mode
set showcmd                                                       " show command on the right side (leader key)
set textwidth=72                                                  " enough for line numbers + gutter within 80 standard
set tabstop=2                                                     " number of spaces that a <Tab> has
set shiftwidth=2                                                  " number of spaces on indentation
set softtabstop=2                                                 " read :help 😂
set numberwidth=2
set smartindent
set autoindent                                                    " automatically indent new lines
set smarttab
set expandtab                                                     " replace tabs /w spaces
set nofixendofline                                                " stop vim from adding \n to files
set foldmethod=manual                                             " no folding
set nofoldenable                                                  " no folding
set laststatus=2

match ErrorMsg '\s\+$'                                            " mark trailing spaces as errors
set shortmess=aoOtTI                                              " avoid most of the 'Hit Enter ...' messages

set hidden                                                        " stop complaints about switching buffer with changes
set history=100                                                   " command history
set updatetime=300

" highlight search hits
set hlsearch
set incsearch
set linebreak
nnoremap <C-l> :nohl<CR><C-l>

" more risky, but cleaner
set nobackup
set noswapfile
set nowritebackup

set completeopt=menuone,noinsert,noselect													" config of vim autocomplete panel
set complete+=kspell                                              " spelling on autocomplete
set shortmess+=c                                                  " remove the autocomplete status bar

" not bracket matching or folding
let g:loaded_matchparen=1
set noshowmatch

" add portuguese dictionary
set spelllang+=pt_pt
set encoding=utf-8

" on yank copy to clipboard
set clipboard+=unnamedplus

" set the cursor fat on insert
set guicursor=i:block

" Return to last edit position when opening files
au BufReadPost *
			\ if line("'\"") > 0 && line("'\"") <= line("$") |
			\   exe "normal! g`\"" |
			\ endif


" ============================================================
" Path (Files to Ignore)
" ============================================================

set path+=**
set wildmenu
" Ignore this files
set wildignore+=**/node_modules/**
set wildignore+=*_build/*
set wildignore+=**/coverage/*
set wildignore+=**/node_modules/*
set wildignore+=**/android/*
set wildignore+=**/ios/*
set wildignore+=**/.git/*
set wildignore+=**/.supabase/*

" ============================================================
" Custom Settings per FileType
" ============================================================

au FileType markdown setlocal conceallevel=2 spell nonumber noautoindent
au FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

" ============================================================
" Commands (Useful for file managing, etc)
"
"* Useful: https://dev.to/dlains/create-your-own-vim-commands-415b
" ============================================================

command! -complete=file -nargs=1 -bar Remove :call delete(expand(<f-args>)) | bd #
command! -complete=file -nargs=1 Rename try | saveas <args> | call delete(expand('#')) | bd # | endtry

" ============================================================
" Netrw (file explorer)
" ============================================================
nnoremap \ :Explore<CR>
let g:netrw_browsex_viewer="cmd.exe /C start"
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_keepdir = 0
let g:netrw_list_hide = &wildignore
let g:netrw_localrmdir='rm -r'

function! NetrwMappings()
	nmap <buffer> . gh
	nmap <buffer> l <CR>
	nmap <buffer> P <C-w>z
	nmap <buffer> <tab> mf
endfunction
autocmd FileType netrw call NetrwMappings()

" ============================================================
" Bindings
" ============================================================

let mapleader = ","

nnoremap <leader>vu :so $HOME/.config/nvim/init.vim<CR>
nnoremap <leader>ve :e $HOME/.config/nvim/init.vim<CR>

" Tab on visual selected
vmap <Tab> >gv
vmap <S-Tab> <gv

" Navigation
nnoremap <silent> <leader>b :Buffers<CR>
nnoremap <silent> <leader>hi :History<CR>
nnoremap <silent> <leader>hc :History:<CR>
nnoremap <silent> <C-p> :FZF<CR>

" <F NUM> Mappings
nnoremap <F1> :set spell!<CR>
nnoremap <leader>2 :set paste<CR>i

" ==========================================================
" Vimdiff
" =========================================================

if &diff
	noremap <leader>1 :diffget LOCAL<CR>
	noremap <leader>2 :diffget BASE<CR>
	noremap <leader>3 :diffget REMOTE<CR>:q
	noremap <C-k> ]c
	noremap <C-j> [c
endif

" ==========================================================
" Remove whitespace
" =========================================================
autocmd FileWritePre * %s/\s\+$//e | nohl
autocmd FileAppendPre * %s/\s\+$//e | nohl
autocmd FilterWritePre * %s/\s\+$//e | nohl
autocmd BufWritePre * %s/\s\+$//e | nohl

" ============================================================
" Formatters
" ============================================================
fun! s:Format()
	let search = @/
	let cursor_position = getpos('.')
	normal! H
	let window_position = getpos('.')
	call setpos('.', cursor_position)
	silent execute 'normal gg=G'
	let @/ = search
	call setpos('.', window_position)
	normal! zt
	call setpos('.', cursor_position)
endfun

augroup default_formatter
	autocmd!
	autocmd FileType vim,sql au BufWritePre <buffer> call s:Format()
augroup end

" ============================================================
" Lint/Checkers <F3>
" ============================================================

au FileType bash,sh nnoremap <buffer> <F3> :w<CR>:!clear && shellcheck %<CR>
au FileType yaml nnoremap <buffer> <F3> :w<CR>:!clear && yamllint %<CR>
au FileType sql nnoremap <buffer> <F3> :w<CR>:!clear && squawk %<CR>

" ==========================================================
" Run Code <F4>
" ==========================================================

au FileType sh nnoremap <buffer> <F4> :w<CR>:!clear && sh %<CR>
au FileType bash nnoremap <buffer> <F4> :w<CR>:!clear && bash %<CR>

" ==========================================================
" Plugins
" ==========================================================

call plug#begin()

Plug 'navarasu/onedark.nvim'
Plug 'sheerun/vim-polyglot'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'tpope/vim-commentary'
Plug 'vitalk/vim-simple-todo'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'hoob3rt/lualine.nvim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'lifepillar/pgsql.vim'
Plug 'vim-scripts/dbext.vim'

call plug#end()

" psql.vim
let g:sql_type_default = 'pgsql'

" dbext -- :h dbext-tutorial
" <leader>sbp - select db conn
" <leader>se - execute
" <leader>sel - execute line
" <leader>st - display contents of table
" <leader>sT - display contents of table (prompts the nr of rows)
"
" <leader>stw - display contents of table (prompts to write the where clause)
" <leader>sta - display contents of table (prompts to write tb name)
" <leader>sdt - describe a object
" <leader>sdt+ - describe a object w/ more info (index on the table etc)
let g:dbext_default_profile_wallstreeters = 'type=PGSQL:user=postgres:dbname=postgres:host=localhost:port=5432'
augroup wallstreeters
	au!
	autocmd BufRead */wallstreeters/server/* DBSetOption profile=wallstreeters
augroup end

" ==========================================================
" Colorscheme
" ==========================================================
let g:onedark_style = 'cool'
colorscheme onedark

lua << EOF
require('lualine').setup {
	options = {
		theme = 'onedark'
		},
	sections = {
		lualine_a = {'mode'},
		lualine_b = {'branch'},
		lualine_c = {'filename'},
		lualine_x = {'encoding', 'filetype'},
		lualine_y = {'progress'},
		lualine_z = {'location'}
		},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = {'filename'},
		lualine_x = {'location'},
		lualine_y = {},
		lualine_z = {}
		},
	}
EOF

" ==========================================================
" Color Overrides
" ==========================================================
au FileType * hi SpellBad guifg=white guibg=lightred
au FileType * hi Error guifg=white guibg=lightred
au FileType * hi ErrorMsg guifg=white guibg=lightred

au FileType markdown,pandoc hi Title cterm=bold guifg=#56B6C2 ctermbg=NONE
au FileType markdown,pandoc hi htmlBold cterm=bold guifg=#5AB0F6 ctermbg=NONE
au FileType markdown,pandoc hi htmlItalic cterm=italic guifg=#E5C07B ctermbg=NONE
au FileType markdown,pandoc hi htmlLink guifg=#56B6C2 cterm=underline gui=underline ctermbg=NONE

" vimdiff
hi DiffText cterm=none gui=none guifg=lightgreen guibg=#242B38
hi DiffChange cterm=none gui=none guifg=#8B96A9 guibg=#242B38
hi DiffAdd cterm=none gui=none guifg=#8B96A9 guibg=#242B38
hi DiffDelete cterm=none gui=none guifg=lightred guibg=#242B38

" background transparent
hi! Normal ctermbg=NONE guibg=NONE
hi! NonText ctermbg=NONE guibg=NONE
hi! EndOfBuffer guibg=NONE ctermbg=NONE

" highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" ==========================================================
" CoC Configs
" ==========================================================

" Merge signcolumn and number into one
if has("nvim-0.5.0") || has("patch-8.1.1564")
	" Recently vim can merge signcolumn and number column into one
	set signcolumn=number
else
	set signcolumn=yes
endif

" Use tab for trigger completion, and UltiSnips triggering
imap <silent><expr> <Tab>
			\ pumvisible() ? coc#_select_confirm() :
			\ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
			\ <SID>check_back_space() ? "\<TAB>" :
			\ coc#refresh()

function! s:check_back_space() abort
	let col = col('.') - 1
	return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Get snippets from here: https://github.com/honza/vim-snippets
" You don't need to install 'SirVer/ultisnips' because of coc-snippets
let g:coc_snippet_next = '<c-j>'
let g:coc_snippet_prev = '<c-k>'
nnoremap <leader>se :CocCommand snippets.editSnippets<CR>

" Diagnostics
nnoremap <silent><nowait> <leader>d  :<C-u>CocList diagnostics<cr>
nmap <silent> <C-j> <Plug>(coc-diagnostic-prev)
nmap <silent> <C-k> <Plug>(coc-diagnostic-next)
" Actions
nmap <leader>rn <Plug>(coc-rename)
nmap <leader>f  <Plug>(coc-codeaction-line)
" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
" Use gh to show documentation in preview window.
nnoremap <silent> gh :call <SID>show_documentation()<CR>
function! s:show_documentation()
	if (index(['vim','help'], &filetype) >= 0)
		execute 'h '.expand('<cword>')
	elseif (coc#rpc#ready())
		call CocActionAsync('doHover')
	else
		execute '!' . &keywordprg . " " . expand('<cword>')
	endif
endfunction

