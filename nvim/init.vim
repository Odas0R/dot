set tw=72 fo=cq wm=0 " no automatic wrapping, rewrapping will wrap to 72

set tabstop=2
set softtabstop=-1
set shiftwidth=0
set shiftround
set expandtab
set autoindent

set autowrite
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
set updatetime=250

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
set mouse=a

" stop the automatic folding madness
set foldmethod=manual
set nofoldenable

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

" Triger `autoread` when files changes on disk
" https://unix.stackexchange.com/questions/149209/refresh-changed-content-of-file-opened-in-vim/383044#383044
" https://vi.stackexchange.com/questions/13692/prevent-focusgained-autocmd-running-in-command-line-editing-mode
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI *
      \ if mode() !~ '\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif

" Notification after file change
" https://vi.stackexchange.com/questions/13091/autocmd-event-for-autoread
autocmd FileChangedShellPost *
      \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None

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
  au FileType markdown setl conceallevel=2 spell norelativenumber tw=62
  au FileType text setl conceallevel=2 spell norelativenumber tw=72
  au BufRead *.env* setl ft=config
augroup end

nnoremap \ :Defx -search=`expand('%:p')` `expand('%:p:h')`<CR>
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

" 
" Bindings
"

let g:mapleader = ","

nnoremap <leader>vu :so ~/.config/nvim/init.vim<CR>
nnoremap <leader>ve :e ~/.config/nvim/init.vim<CR>

" Navigation
nnoremap <silent> <C-p> <cmd>Telescope git_files<cr>
nnoremap <silent> <C-g> <cmd>Telescope live_grep<cr>
nnoremap <silent> <leader>b <cmd>Telescope buffers<cr>
nnoremap <silent> <leader>d <cmd>Telescope diagnostics<cr>

" Move through errors on qf panel
nnoremap <silent> <C-j> :cnext<CR>
nnoremap <silent> <C-k> :cprev<CR>

" Move through buffers
nnoremap <silent> L :bnext<CR>
nnoremap <silent> H :bprev<CR>

" <leader> Mappings (like f1, f2,...)
nnoremap <silent> <leader>1 :set spell!<CR>
nnoremap <silent> <leader>p :set paste!<CR>

"
" Run Code...
" 
augroup run_code
  au!
  " bash
  au FileType sh xnoremap <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <leader>rp vapyPgv:!bash<CR>

  " sql
  au FileType sql xnoremap <leader>r :DB<CR>
  au FileType sql nnoremap <leader>rp vap:DB<CR>
augroup end

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

" newtr replacement because newtr sucks
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }

" database
Plug 'tpope/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-completion'

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

" formatter
Plug 'lukas-reineke/format.nvim'

" snippet Engine
Plug 'sirver/UltiSnips'

" writing
Plug 'preservim/vim-markdown'

call plug#end()

" 
" Markdown
"

set conceallevel=2

let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal_code_blocks = 1
let g:vim_markdown_new_list_item_indent = 2
let g:vim_markdown_no_extensions_in_markdown = 0
let g:vim_markdown_autowrite = 1
let g:vim_markdown_edit_url_in = 'current'

" 
" Colorscheme
"

let g:tokyonight_style = "night"
let g:tokyonight_italic_functions = 1
colorscheme tokyonight

"
" Color Overrides
"

au FileType * hi SpellBad ctermbg=NONE ctermfg=Red cterm=underline
au FileType * hi Error ctermbg=NONE ctermfg=Red
au FileType * hi ErrorMsg ctermbg=NONE ctermfg=Red

highlight Title gui=bold guifg=#e0af68 ctermfg=yellow
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
" Formatter
" 

" let g:format_debug = v:true
augroup Format
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
