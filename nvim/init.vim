set nocompatible

syntax on
filetype plugin on
filetype indent on
set ttyfast

set autowrite
set relativenumber
set ruler
set showmode
set showcmd
" set textwidth=72
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
set nofoldenable
set laststatus=2

match ErrorMsg '\s\+$'
set shortmess=aoOtTI

set hidden
set history=100
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
augroup init_settings
  au FileType markdown setl conceallevel=2 spell norelativenumber noautoindent textwidth=72
  au FileType yaml setl ts=2 sts=2 sw=2 expandtab
augroup end

" ============================================================
" Commands (Useful for file managing, etc)
"
"* Useful: https://dev.to/dlains/create-your-own-vim-commands-415b
" ============================================================

command! -complete=file -nargs=1 -bar Remove :call delete(expand(<f-args>)) | bd #
command! -complete=file -nargs=1 Rename try | saveas <args> | call delete(expand('#')) | bd # | endtry

" run own bash programs
command! Daily :silent !daily
command! Prevday :silent !prevday
command! Todos :silent !todos
command! Habits :silent !habits
command! Goals :silent !goals
command! Workflow :silent !workflow
command! Tech :silent !tech

command! -nargs=1 Cmd :silent !cmd <args>

" ============================================================
" Netrw (file explorer)
" ============================================================
nnoremap \ :Explore<CR>
let g:netrw_browsex_viewer="cmd.exe /C start"
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_keepdir = 1
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

nnoremap <leader>vu :so ~/.vimrc<CR>
nnoremap <leader>ve :e ~/.vimrc<CR>

" Navigation
nnoremap <silent> <leader>ls :Buffers<CR>
nnoremap <silent> <C-p> :FzfBat<CR>
nnoremap <silent> <C-j> :cnext<CR>
nnoremap <silent> <C-k> :cprev<CR>

" <leader> Mappings (like f1, f2,...)
nnoremap <F1> :set spell!<CR>
nnoremap <leader>2 :set paste<CR>i

" ==========================================================
" Run Code...
" =========================================================
augroup run_code
  au!
  au FileType sh xnoremap <leader>r yPgv:!bash<CR>
  au FileType sh nnoremap <leader>rp vapyPgv:!bash<CR>
augroup end

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
" Plugins
" ==========================================================

call plug#begin()

" Syntax, Highlighting
Plug 'gruvbox-community/gruvbox'
Plug 'sheerun/vim-polyglot'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'lifepillar/pgsql.vim'
Plug 'ap/vim-css-color'

" Find, Fuzzy
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Status line
Plug 'hoob3rt/lualine.nvim'
Plug 'nvim-lua/lsp-status.nvim'

" Util
Plug 'tpope/vim-commentary'
Plug 'vim-scripts/dbext.vim'
Plug 'tpope/vim-fugitive'

" Lsp, Completion Engine
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-lua/completion-nvim'
Plug 'aca/completion-tabnine', { 'do': './install.sh' }

" Formatter
Plug 'lukas-reineke/format.nvim'

" Snippet Engine
Plug 'sirver/UltiSnips'

" Writing
Plug 'vim-pandoc/vim-pandoc'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}

call plug#end()

" ==========================================================
" Markdown Writing, Formatting
" ==========================================================
let g:pandoc#formatting#mode = 'ha'
let g:pandoc#formatting#textwidth = 72
let g:pandoc#toc#position = "bottom"
autocmd BufNewFile,BufFilePre,BufRead *.md set filetype=markdown

" ==========================================================
" PSQL w/ dbext plugin
" ==========================================================
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
" StatusLine
" ==========================================================
lua << EOF
local lsp_status = require("lsp-status")
lsp_status.register_progress()

lsp_status.config({
  status_symbol = "",
  indicator_errors = "E",
  indicator_warnings = "W",
  indicator_info = "I",
  indicator_hint = "?",
  indicator_ok = "OK",
})

require("lualine").setup({
  options = { theme = "gruvbox", section_separators = "", component_separators = "" },
  section_separators = {},
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = { "filename", lsp_status.status },
    lualine_x = { "encoding", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  extensions = { "quickfix", "fzf" },
})
EOF

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
" Completion & LSP
" ==========================================================

set completeopt=menuone,noinsert,noselect

autocmd BufEnter * lua require'completion'.on_attach()

let g:UltinipsExpandTrigger="<tab>"
let g:UltiSnipsEditSplit="vertical"
let g:UltiSnipsSnippetDirectories=["~/snippets/ultisnips"]
let g:UltiSnipsJumpForwardTrigger='<c-j>'
let g:UltiSnipsJumpBackwardTrigger='<c-k>'

let g:completion_enable_snippet = 'UltiSnips'
let g:completion_matching_strategy_list=['exact', 'substring', 'fuzzy']
let g:completion_tabnine_sort_by_details=1
let g:completion_chain_complete_list = {
      \ 'default': [
        \    {'complete_items': ['lsp', 'snippet', 'tabnine' ]},
        \    {'mode': '<c-p>'},
        \    {'mode': '<c-n>'}
        \]
        \}

" Use tab to navigate through the popup menu
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Lsp -- configs
lua require("odas0r/lsp")
lua require("odas0r/efm")

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


" ==========================================================
" Formatters
" ==========================================================

augroup Format
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END

" can't make it work with format.nvim
augroup pgFormatter
  au!
  au BufWritePost *.sql if bufname('%')[-8:] != 'test.sql' | :%!pg_format -u 1 -s 2 -C -L
augroup end

lua << EOF
require("format").setup({
  ["*"] = {
    { cmd = { "sed -i 's/[ \t]*$//'" }, tmpfile_dir = "/tmp/" }, -- remove trailing whitespace
  },
  vim = {
    {
      cmd = { "stylua --indent-type Spaces --indent-width 2" },
      start_pattern = "^lua << EOF$",
      end_pattern = "^EOF$",
    },
  },
  lua = {
    {
      cmd = { "stylua --indent-type Spaces --indent-width 2" },
      tmpfile_dir = "/tmp/",
    },
  },
  go = {
    {
      cmd = { "gofmt -w", "goimports -w" },
      tempfile_postfix = ".tmp",
    },
  },
  sh = {
    { cmd = { "shfmt -ci -s -bn -i 2 -w" } },
  },
  javascript = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  javascriptreact = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  typescript = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  typescriptreact = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  json = {
    { cmd = { "fixjson -w", "prettier -w" } },
  },
  jsonc = {
    { cmd = { "fixjson -w", "prettier -w" } },
  },
  html = {
    { cmd = { "prettier -w" } },
  },
  css = {
    { cmd = { "prettier -w" } },
  },
  scss = {
    { cmd = { "prettier -w" } },
  },
  markdown = {
    {
      cmd = { "shfmt -ci -s -bn -i 2 -w" },
      start_pattern = "^```bash$",
      end_pattern = "^```$",
      target = "current",
    },
  },
})
EOF

