set nocompatible

syntax on
filetype plugin on
filetype indent on
set ttyfast

" somehow performance increases
set lazyredraw

set autowrite
set relativenumber
set ruler
set showmode
set showcmd
set tw=72 fo=cq wm=0 " no automatic wrapping, rewrapping will wrap to 72
set tabstop=2
set shiftwidth=2
set softtabstop=2
set numberwidth=2
set smartindent
set autoindent
set smarttab
set expandtab
set nofixendofline
set foldmethod=manual
set laststatus=2
" make :mkview ignore local bidings
set viewoptions-=options

match ErrorMsg '\s\+$'
set shortmess=aoOtTI

set hidden
set history=1000
set updatetime=100

" highlight search hits
set hlsearch
set incsearch
set linebreak
set nowrap " wrap is for psychopaths
nnoremap <C-l> :nohl<CR><C-l>

" more risky, but cleaner
set nobackup
set noswapfile
set nowritebackup

set complete+=kspell
set shortmess+=c

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
set wildignore+=*formatting*/*
set wildignore+=**/coverage/*
set wildignore+=**/node_modules/*
set wildignore+=**/android/*
set wildignore+=**/ios/*
set wildignore+=**/.git/*
set wildignore+=**/.supabase/*

" ============================================================
" Custom Settings per FileType
" ============================================================
augroup custom_settings
  au!
  au FileType markdown setl conceallevel=2 spell norelativenumber tw=76
  au BufRead *.env setl ft=config
augroup end

" ============================================================
" Commands (Useful for file managing, etc)
"
"* Useful: https://dev.to/dlains/create-your-own-vim-commands-415b
" ============================================================

" ============================================================
" File Explorer
" ============================================================
" nnoremap \ :Explore<CR>
" let g:netrw_browsex_viewer="cmd.exe /C start"
" let g:netrw_banner = 0
" let g:netrw_liststyle = 3
" let g:netrw_keepdir = 1
" let g:netrw_list_hide = &wildignore
" " this shit does not work
" let g:netrw_localrmdir='rm -rf'

" function! NetrwMappings()
"   nmap <buffer> . gh
"   nmap <buffer> l <CR>
"   nmap <buffer> P <C-w>z
"   nmap <buffer> <tab> mf
" endfunction

" autocmd FileType netrw call NetrwMappings()
nnoremap \ :Defx `escape(expand('%:p:h'), ' :')` -search=`expand('%:p')`<CR>
function! DefxMappings()
  nnoremap <silent><buffer><expr> c
        \ defx#do_action('copy')
  nnoremap <silent><buffer><expr> m
        \ defx#do_action('move')
  nnoremap <silent><buffer><expr> p
        \ defx#do_action('paste')
  nnoremap <silent><buffer><expr> l
        \ defx#do_action('open_tree', 'toggle')
  nnoremap <silent><buffer><expr> <CR>
        \ defx#do_action('open')
  nnoremap <silent><buffer><expr> P
        \ defx#do_action('preview')
  nnoremap <silent><buffer><expr> d
        \ defx#do_action('new_directory')
  nnoremap <silent><buffer><expr> N
        \ defx#do_action('new_file')
  nnoremap <silent><buffer><expr> M
        \ defx#do_action('new_multiple_files')
  nnoremap <silent><buffer><expr> D
        \ defx#do_action('remove')
  nnoremap <silent><buffer><expr> R
        \ defx#do_action('rename')
  nnoremap <silent><buffer><expr> !
        \ defx#do_action('execute_command')
  " open directory on finder
  nnoremap <silent><buffer><expr> o
        \ defx#do_action('execute_system')
  nnoremap <silent><buffer><expr> yy
        \ defx#do_action('yank_path')
  nnoremap <silent><buffer><expr> .
        \ defx#do_action('toggle_ignored_files')
  nnoremap <silent><buffer><expr> h
        \ defx#do_action('cd', ['..'])
  nnoremap <silent><buffer><expr> q
        \ defx#do_action('quit')
  nnoremap <silent><buffer><expr> <Tab>
        \ defx#do_action('toggle_select') . 'j'
  nnoremap <silent><buffer><expr> <C-7>
        \ defx#do_action('toggle_select_all')
  nnoremap <silent><buffer><expr> j
        \ line('.') == line('$') ? 'gg' : 'j'
  nnoremap <silent><buffer><expr> k
        \ line('.') == 1 ? 'G' : 'k'
  nnoremap <silent><buffer><expr> <C-l>
        \ defx#do_action('redraw')
endfunction
autocmd FileType defx call DefxMappings()

" open defx automatically when :edit a directory
autocmd BufEnter,VimEnter,BufNew,BufWinEnter,BufRead,BufCreate
      \ * if isdirectory(expand('<amatch>'))
      \   | call s:browse_check(expand('<amatch>')) | endif

function! s:browse_check(path) abort
  if bufnr('%') != expand('<abuf>')
    return
  endif
  " Disable netrw.
  augroup FileExplorer
    autocmd!
  augroup END
  execute 'Defx' a:path
endfunction

" ============================================================
" Bindings
" ============================================================

let g:mapleader = ","

nnoremap <leader>vu :so ~/.config/nvim/init.vim<CR>
nnoremap <leader>ve :e ~/.config/nvim/init.vim<CR>

" Navigation
nnoremap <silent> <C-p> :FzfBat<CR>

" Move through errors on qf panel
nnoremap <silent> <C-j> :cnext<CR>
nnoremap <silent> <C-k> :cprev<CR>

" Move through buffers
nnoremap <silent> L :bnext<CR>
nnoremap <silent> H :bprev<CR>

" <leader> Mappings (like f1, f2,...)
nnoremap <silent> <leader>1 :set spell!<CR>
nnoremap <silent> <leader>p :set paste!<CR>

" Open a control-version diff viewer
nnoremap <leader>diff :DiffviewOpen<CR>
nnoremap <leader>q :DiffviewClose<CR>

" Move thorough vimdiff
if &diff
  nnoremap <leader>1 :diffget LOCAL<CR>
  nnoremap <leader>2 :diffget BASE<CR>
  nnoremap <leader>3 :diffget REMOTE<CR>
  map <C-k> ]x
  map <C-j> [x
  nnoremap <leader>q :wqa<CR>
endif

" ==========================================================
" Run Code...
" =========================================================
augroup run_code
  au!
  au FileType sh xnoremap <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <leader>rp vapyPgv:!bash<CR>
augroup end

" ==========================================================
" Plugins
" ==========================================================

call plug#begin()

" Syntax, Highlighting
Plug 'gruvbox-community/gruvbox'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'ap/vim-css-color'
Plug 'fladson/vim-kitty'
Plug 'sheerun/vim-polyglot'

" Find, Fuzzy
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Status line
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-lua/lsp-status.nvim'

" Utils
Plug 'tpope/vim-commentary'
Plug 'suy/vim-context-commentstring'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'nvim-lua/plenary.nvim'

" Git
Plug 'sindrets/diffview.nvim'
Plug 'rhysd/conflict-marker.vim'

" newtr replacement because newtr sucks
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }

" Lsp, Completion Engine
Plug 'neovim/nvim-lspconfig'
Plug 'onsails/lspkind-nvim'

" Completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'tzachar/cmp-tabnine', { 'do': './install.sh' }
Plug 'quangnguyen30192/cmp-nvim-ultisnips'

" Formatter
Plug 'lukas-reineke/format.nvim'

" Snippet Engine
Plug 'sirver/UltiSnips'

" Writing
Plug 'vim-pandoc/vim-pandoc'

call plug#end()

" ==========================================================
" Markdown Writing, Formatting
" ==========================================================
let g:pandoc#formatting#mode = 'ha'
let g:pandoc#formatting#textwidth = 72
let g:pandoc#toc#position = "bottom"
autocmd BufNewFile,BufFilePre,BufRead *.md set filetype=markdown

augroup remember_folds
  autocmd!
  autocmd BufWinLeave *.* mkview
  autocmd BufWinEnter *.* silent! loadview
augroup END

" ==========================================================
" Colorscheme
" ==========================================================
let g:gruvbox_contrast_dark = 'dark'
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
endif
let g:gruvbox_invert_selection='0'
let g:gruvbox_termcolors=16
let g:gruvbox_italic=1
set background=dark
colorscheme gruvbox
set t_Co=256 " iterm shit

" ==========================================================
" Git
" ==========================================================
lua << EOF
require("diffview").setup({
  use_icons = false,
})
EOF

" Conflict Marker
let g:conflict_marker_begin = '^<<<<<<< \@='
let g:conflict_marker_common_ancestors = '^||||||| .*$'
let g:conflict_marker_separator = '^=======$'
let g:conflict_marker_end   = '^>>>>>>> \@='
let g:conflict_marker_enable_highlight = 1
let g:conflict_marker_highlight_group = 'Error'


" Include text after begin and end markers
let g:conflict_marker_begin = '^<<<<<<< .*$'
let g:conflict_marker_end   = '^>>>>>>> .*$'

highlight ConflictMarkerBegin guibg=#2f7366
highlight ConflictMarkerOurs guibg=#2e5049
highlight ConflictMarkerTheirs guibg=#344f69
highlight ConflictMarkerEnd guibg=#2f628e
highlight ConflictMarkerCommonAncestorsHunk guibg=#754a81

" ==========================================================
" FZF
" ==========================================================

let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.8 } }
let g:fzf_preview_window = ['right:70%']

" Better FZF
command! -bang -nargs=? -complete=dir FzfBat
      \ call fzf#vim#files(<q-args>, {'options': ['--layout=reverse', '--info=inline', '--preview', 'bat --theme="gruvbox-dark" --color=always --style=numbers {}']}, <bang>0)

function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case -w -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

command! -nargs=* -bang Grep call RipgrepFzf(<q-args>, <bang>0)

" ==========================================================
" Color Overrides
" ==========================================================

au FileType * hi SpellBad ctermbg=NONE ctermfg=Red cterm=underline
au FileType * hi Error ctermbg=NONE ctermfg=Red
au FileType * hi ErrorMsg ctermbg=NONE ctermfg=Red

au FileType markdown hi Title cterm=bold ctermbg=none ctermfg=Yellow
au FileType markdown hi htmlBold cterm=bold ctermbg=none ctermfg=Cyan
au FileType markdown hi htmlItalic cterm=italic ctermbg=none ctermfg=Magenta

" vimdiff
hi DiffText cterm=none ctermfg=lightgreen guibg=none
hi DiffChange cterm=none ctermfg=Green guibg=none
hi DiffAdd cterm=none ctermfg=Green guibg=none
hi DiffDelete cterm=none ctermfg=lightred guibg=none

" background transparent
hi Normal guibg=none ctermbg=none
hi NonText guibg=none ctermbg=none
hi EndOfBuffer guibg=none ctermbg=none
hi SignColumn guibg=none ctermbg=none
hi LineNr guibg=none ctermbg=none
hi CursorLineNr guibg=none ctermbg=none

" Color matching parenthesis
hi MatchParen guibg=lightgray

" ==========================================================
" Completion, UltiSnips
" ==========================================================

" Please read `:help ins-completion`.

set completeopt=menuone,noinsert,noselect

" UltiSnips
let g:UltinipsExpandTrigger="<tab>"
let g:UltiSnipsEditSplit="vertical"
let g:UltiSnipsSnippetDirectories=["~/snippets/ultisnips"]
let g:UltiSnipsJumpForwardTrigger='<c-j>'
let g:UltiSnipsJumpBackwardTrigger='<c-k>'

" ==========================================================
" Tree-sitter
" ==========================================================

lua << EOF
require("nvim-treesitter.configs").setup({
  ensure_installed = "maintained",
  indent = { enable = true },
  highlight = {
    enable = true,
    disable = { "vim", "markdown" },
  },
  incremental_selection = { enable = true },
  textobjects = { enable = true },
})
EOF

" let g:format_debug = v:true
augroup Format
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
