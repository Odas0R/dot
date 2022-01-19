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
  au FileType markdown setl conceallevel=2 spell norelativenumber tw=76
  au FileType text setl conceallevel=2 spell norelativenumber tw=76
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

" ==========================================================
" Run Code...
" =========================================================
augroup run_code
  au!
  " bash
  au FileType sh xnoremap <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <leader>rp vapyPgv:!bash<CR>

  " sql
  au FileType sql xnoremap <leader>r :DB<CR>
  au FileType sql nnoremap <leader>rp vap:DB<CR>
augroup end

" ==========================================================
" Plugins
" ==========================================================

call plug#begin()

" treesitter shit
Plug 'folke/tokyonight.nvim', { 'branch': 'main' }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'windwp/nvim-ts-autotag'
Plug 'nvim-treesitter/nvim-treesitter-refactor'

" find, fuzzy
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" status line
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-lua/lsp-status.nvim'

" utils
Plug 'numToStr/Comment.nvim'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'nvim-lua/plenary.nvim'

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
Plug 'vim-pandoc/vim-pandoc'

call plug#end()

" ==========================================================
" Markdown Writing, Formatting
" ==========================================================
let g:pandoc#formatting#mode = 'ha'
let g:pandoc#formatting#textwidth = 72
let g:pandoc#toc#position = "bottom"
autocmd BufNewFile,BufFilePre,BufRead *.md set filetype=markdown

" ==========================================================
" Colorscheme
" ==========================================================

let g:tokyonight_style = "night"
let g:tokyonight_italic_functions = 1
let g:tokyonight_sidebars = [ "qf", "terminal", "plug" ]

colorscheme tokyonight

" ==========================================================
" FZF
" ==========================================================

let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.8 } }
let g:fzf_preview_window = ['right:70%']

" Better FZF
command! -bang -nargs=? -complete=dir FzfBat
      \ call fzf#vim#files(<q-args>, {'options': ['--layout=reverse', '--info=inline', '--preview', 'bat --theme="ansi" --color=always --style=numbers {}']}, <bang>0)

function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case -- %s || true'
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

highlight Title gui=bold guifg=#e0af68 ctermfg=yellow
highlight htmlBold gui=bold guifg=#e0af68 ctermfg=214
highlight htmlItalic gui=italic guifg=#bb9af7 ctermfg=214

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
" Autocomplete Postgresql
" ==========================================================
let g:db="postgres://postgres:postgres@localhost:5432/postgres"
let g:vim_dadbod_completion_mark = 'SQL'
let g:completion_matching_ignore_case = 1

" ==========================================================
" Formatter
" ==========================================================

" let g:format_debug = v:true
augroup Format
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
