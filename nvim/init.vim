set tw=79 fo=cq wm=0 " no automatic wrapping, rewrapping will wrap to 79

set tabstop=2
set softtabstop=-1
set shiftwidth=0
set shiftround
set expandtab
set autoindent

set relativenumber

set autoread
set autowriteall
set number
set ruler
set showmode

set termguicolors

" set the winbar on top-right instead of bottom-left
" https://www.youtube.com/watch?v=LKW_SUucO-k
set winbar=%=%m\ %f
set showcmd
set cmdheight=1
set laststatus=2

" experimentation for performance
set lazyredraw
set synmaxcol=200
set ttyfast

set numberwidth=2
set nofixendofline
set foldmethod=manual
set noshowmatch

set shortmess=aoOtTI

set hidden
set history=1000
set updatetime=100

" highlight search hits
set hlsearch
set incsearch
set linebreak
set nowrap

" more risky, but cleaner
set nobackup
set noswapfile
set nowritebackup

set completeopt=menuone,noinsert,noselect
set complete+=kspell
set shortmess+=c
set mouse=a

" set folding
set foldmethod=manual

" add portuguese dictionary
set spelllang+=pt_pt
set encoding=utf-8

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
  au FileType text setl conceallevel=2 spell norelativenumber tw=72
  au BufRead *.env* setl ft=config

  " missing filetype on .astro
  autocmd BufRead,BufEnter *.astro set filetype=astro
augroup end

"
" Bindings
"
let g:mapleader = ","

nnoremap <leader>vu :so ~/.config/nvim/init.vim<CR>

nnoremap <silent> <leader>s :set spell!<CR>
nnoremap <silent> <leader>p :set paste!<CR>

nnoremap <C-l> :nohl<CR><C-l>

" Buffers management
nnoremap <silent> <leader>bn <cmd>bnext<cr>
nnoremap <silent> <leader>bp <cmd>bprevious<cr>
nnoremap <silent> <leader>bd <cmd>bdelete<cr>
nnoremap <silent> <leader>bl <cmd>Telescope buffers<cr>

" disable macros
map <silent> Q <nop>
map <silent> qq <nop>

"
" Plugins
"

call plug#begin('~/.config/nvim/plugged')

" theme
Plug 'ellisonleao/gruvbox.nvim'

" treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" status line
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-lua/lsp-status.nvim'

" utils, fuzzy-finder, etc.
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'windwp/nvim-ts-autotag'
Plug 'ThePrimeagen/harpoon'
Plug 's1n7ax/nvim-terminal'
Plug 'mhinz/vim-signify'
Plug 'rcarriga/nvim-notify'
Plug 'isobit/vim-caddyfile'

" comments, utilities for documentation
Plug 'numToStr/Comment.nvim'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'jose-elias-alvarez/typescript.nvim'
Plug 'wakatime/vim-wakatime'

" newtr replacement because newtr sucks
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'kristijanhusak/defx-git'

" database
Plug 'tpope/vim-dadbod'

" lsp, Completion Engine
Plug 'neovim/nvim-lspconfig'
Plug 'onsails/lspkind-nvim'

" completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'quangnguyen30192/cmp-nvim-ultisnips'

Plug 'github/copilot.vim'

" formatter
Plug 'mhartington/formatter.nvim'

" snippet Engine
Plug 'sirver/UltiSnips'

" writing
Plug 'preservim/vim-markdown'

call plug#end()

"
" Color Overrides
"

au FileType * hi SpellBad ctermbg=NONE ctermfg=Red cterm=underline
au FileType * hi Error ctermbg=NONE ctermfg=Red
au FileType * hi ErrorMsg ctermbg=NONE ctermfg=Red

hi MatchParen guibg=lightgray guifg=black

lua << EOF
  -- import all configs
  require("odas0r")
  require("plenary.reload").reload_module("odas0r", true)
EOF
