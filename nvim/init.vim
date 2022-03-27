set tw=72 fo=cq wm=0 " no automatic wrapping, rewrapping will wrap to 72

set tabstop=2
set softtabstop=-1
set shiftwidth=0
set shiftround
set expandtab
set autoindent

set autoread 
set autowriteall
set relativenumber
set ruler
set showmode
set showcmd

set numberwidth=2
set laststatus=2
set nofixendofline
set foldmethod=manual
set noshowmatch

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

" more risky, but cleaner
set nobackup
set noswapfile
set nowritebackup

set complete+=kspell
set shortmess+=c
set mouse=a

" set folding
set foldmethod=manual

" add portuguese dictionary
set spelllang+=pt_pt
set encoding=utf-8

" set the cursor fat on insert
" set guicursor=i:block

" Return to last edit position when opening files
au BufReadPost *
      \ if line("'\"") > 0 && line("'\"") <= line("$") |
      \   exe "normal! g`\"" |
      \ endif

"
" Path (Files to Ignore)
"

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

"
" Custom Settings per FileType
" 
augroup custom_settings
  au!
  au FileType markdown setl conceallevel=2 spell norelativenumber tw=72 foldlevel=99
  au FileType text setl conceallevel=2 spell norelativenumber tw=72
  au BufRead *.env* setl ft=config
augroup end

" 
" Bindings
"
let g:mapleader = ","

nnoremap <silent> Q <nop>

nnoremap <leader>vu :so ~/.config/nvim/init.vim<CR>

nnoremap <silent> <leader>s :set spell!<CR>
nnoremap <silent> <leader>p :set paste!<CR>

nnoremap <C-l> :nohl<CR><C-l>

"
" Plugins
" 

call plug#begin()

" treesitter shit
Plug 'folke/tokyonight.nvim', { 'branch': 'main' }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'windwp/nvim-ts-autotag'
Plug 'nvim-treesitter/nvim-treesitter-refactor'

" status line
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-lua/lsp-status.nvim'

" utils, fuzzy-finder, etc.
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'numToStr/Comment.nvim'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'ThePrimeagen/harpoon'
Plug 'caenrique/nvim-toggle-terminal'
Plug 'mhinz/vim-signify'

" newtr replacement because newtr sucks
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }

" database
" fork of https://github.com/tpope/vim-dadbod (I believe this is faster)
Plug 'kristijanhusak/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-completion'

" lsp, Completion Engine
Plug 'neovim/nvim-lspconfig'
Plug 'onsails/lspkind-nvim'
Plug 'jose-elias-alvarez/nvim-lsp-ts-utils'

" yank over OSC
Plug 'ojroques/vim-oscyank', {'branch': 'main'}

" completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'quangnguyen30192/cmp-nvim-ultisnips'

" formatter
" Plug 'lukas-reineke/format.nvim'
Plug 'mhartington/formatter.nvim'

" snippet Engine
Plug 'sirver/UltiSnips'

" documentation
Plug 'heavenshell/vim-jsdoc', {
  \ 'for': ['javascript', 'javascriptreact','typescript', 'typescriptreact'],
  \ 'do': 'make install'
\}

" writing
Plug 'preservim/vim-markdown'

call plug#end()

"
" Color Overrides
"

au FileType * hi SpellBad ctermbg=NONE ctermfg=Red cterm=underline
au FileType * hi Error ctermbg=NONE ctermfg=Red
au FileType * hi ErrorMsg ctermbg=NONE ctermfg=Red

highlight htmlTitle gui=bold guifg=#e0af68 ctermfg=Yellow
highlight htmlBold gui=bold guifg=#e0af68 ctermfg=214
highlight htmlItalic gui=italic guifg=#bb9af7 ctermfg=214

hi MatchParen guibg=lightgray

"
" Completion, UltiSnips
"
" read `:help ins-completion`.

set completeopt=menuone,noinsert,noselect

let g:UltinipsExpandTrigger="<tab>"
let g:UltiSnipsEditSplit="vertical"
let g:UltiSnipsSnippetDirectories=["~/snippets/ultisnips"]
let g:UltiSnipsJumpForwardTrigger='<Tab>'
let g:UltiSnipsJumpBackwardTrigger='<S-Tab>'

" 
" Database SQL Autocompletion
" 
let g:db="postgres://postgres:postgres@localhost:5432/postgres"
let g:vim_dadbod_completion_mark = 'SQL'
let g:completion_matching_ignore_case = 1


" 
" Folding
" 
let g:markdown_folding = 1

augroup remember_folds
  autocmd!
  autocmd BufWinLeave *.md mkview
  autocmd BufWinEnter *.md silent! loadview
augroup END

lua << EOF
  -- import all configs
  require("odas0r")

  -- Reload modules on save
  require("plenary.reload").reload_module("odas0r", true)
EOF
