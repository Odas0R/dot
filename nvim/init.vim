set nocompatible

syntax on                                                         " syntax for plugins etc
filetype plugin on                                                " allow sensing the file type
set ttyfast                                                       " faster scrolling

set autowrite                                                     " automatically write files when changing when multiple files open
set relativenumber
set ruler                                                         " turn col and row position on in bottom right
set showmode                                                      " show command and insert mode
set showcmd                                                       " show command on the right side (leader key)
" set textwidth=72                                                " enough for line numbers + gutter within 80 standard
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

set complete+=kspell                                              " spelling on autocomplete
set shortmess+=c                                                  " remove the autocomplete status bar

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

au FileType markdown setl conceallevel=2 spell norelativenumber noautoindent textwidth=72
au FileType yaml setl ts=2 sts=2 sw=2 expandtab

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
nnoremap <silent> <leader>hc :History:<CR>
nnoremap <silent> <C-p> :FZF<CR>
nnoremap <silent> <C-j> :cnext<CR>
nnoremap <silent> <C-k> :cprev<CR>

" <leader> Mappings (like f1, f2,...)
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

" Util
Plug 'tpope/vim-commentary'
Plug 'hoob3rt/lualine.nvim'
Plug 'vim-scripts/dbext.vim'

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
" Pandoc: Writing
" ==========================================================
  let g:pandoc#formatting#mode = 'h'
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
" let g:gruvbox_contrast_dark = 'dark'
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
endif
let g:gruvbox_invert_selection='0'
let g:gruvbox_termcolors=16
let g:gruvbox_italic=1
set background=dark
colorscheme gruvbox

lua << EOF
require("lualine").setup({
  options = {
    theme = "gruvbox",
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = { "filename" },
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
})
EOF

" ==========================================================
" FZF
" ==========================================================

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.9 } }

let g:fzf_preview_window = ['right:70%']
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

" Lsp
lua require("lsp")

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
      tmpfile_dir = "/tmp/",
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
      tmpfile_dir = "/tmp/",
    },
  },
  json = {
    { cmd = { "prettier -w" }, tmpfile_dir = "/tmp/" },
  },
  javascript = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" }, tmpfile_dir = "/tmp/" },
  },
  javascriptreact = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" }, tmpfile_dir = "/tmp/" },
  },
  typescript = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" }, tmpfile_dir = "/tmp/" },
  },
  typescriptreact = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" }, tmpfile_dir = "/tmp/" },
  },
  sh = {
    { cmd = { "shfmt -i 2 -w" }, tmpfile_dir = "/tmp/" },
  },
  markdown = {
    {
      cmd = { "shfmt -i 2 -w" },
      start_pattern = "^```bash$",
      end_pattern = "^```$",
      target = "current",
      tmpfile_dir = "/tmp/",
    },
  },
})
EOF
