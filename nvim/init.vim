set tw=79 fo=cq wm=0 " no automatic wrapping, rewrapping will wrap to 79

set tabstop=2
set softtabstop=-1
set shiftwidth=0
set shiftround
set expandtab
set autoindent

set autoread 
set autowriteall
set number
set ruler
set showmode

" set the winbar on top-right instead of bottom-left
" https://www.youtube.com/watch?v=LKW_SUucO-k
" set winbar=%=%m\ %f
" set cmdheight=1
" set showcmd

set laststatus=2

" experimentation for performance
set lazyredraw
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

nnoremap <silent> Q <nop>

nnoremap <leader>vu :so ~/.config/nvim/init.vim<CR>

nnoremap <silent> <leader>s :set spell!<CR>
nnoremap <silent> <leader>p :set paste!<CR>

nnoremap <silent> <leader><leader>g :!lzg<CR>

nnoremap <C-l> :nohl<CR><C-l>

" Buffers management
nnoremap <silent> <leader>bn <cmd>bnext<cr>
nnoremap <silent> <leader>bp <cmd>bprevious<cr>
nnoremap <silent> <leader>bd <cmd>bdelete<cr>
nnoremap <silent> <leader>bl <cmd>Telescope buffers<cr>

" disable macros
map qq <nop>

"
" Plugins
" 

call plug#begin()

" theme
Plug 'ellisonleao/gruvbox.nvim'

" treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/playground'

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


" comments, utilities for documentation
Plug 'numToStr/Comment.nvim'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'jose-elias-alvarez/nvim-lsp-ts-utils'
Plug 'wakatime/vim-wakatime'

" newtr replacement because newtr sucks
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'kristijanhusak/defx-git'

" database
" fork of https://github.com/tpope/vim-dadbod (I believe this is faster)
Plug 'kristijanhusak/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-completion'

" lsp, Completion Engine
Plug 'neovim/nvim-lspconfig'
Plug 'onsails/lspkind-nvim'

" yank over OSC
" Plug 'ojroques/vim-oscyank', {'branch': 'main'}

" completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'quangnguyen30192/cmp-nvim-ultisnips'
Plug 'tzachar/cmp-tabnine', { 'do': './install.sh' }

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

lua << EOF
  -- import all configs
  require("odas0r")
  require("plenary.reload").reload_module("odas0r", true)
EOF
