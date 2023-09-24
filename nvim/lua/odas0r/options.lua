-----------------------------------------
-- Options
-----------------------------------------

-- copy-paste from
-- <https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua>

local opt = vim.opt

opt.textwidth = 80 -- Maximum width of text
-- opt.colorcolumn = "80" -- Line length marker
opt.formatoptions = "jcroqlnt" -- tcqj

opt.autowrite = true -- Enable auto write
opt.clipboard = "unnamedplus" -- Sync with system clipboard
opt.completeopt = "menu,menuone,noselect"
opt.conceallevel = 3 -- Hide * markup for bold and italic
opt.confirm = true -- Confirm to save changes before exiting modified buffer
opt.cursorline = true -- Enable highlighting of the current line
opt.expandtab = true -- Use spaces instead of tabs
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"
opt.ignorecase = true -- Ignore case
opt.inccommand = "nosplit" -- preview incremental substitute
opt.laststatus = 0
opt.list = true -- Show some invisible characters (tabs...
opt.mouse = "a" -- Enable mouse mode
opt.number = true -- Print line number
opt.pumblend = 10 -- Popup blend
opt.pumheight = 10 -- Maximum number of entries in a popup
opt.relativenumber = true -- Relative line numbers
opt.scrolloff = 4 -- Lines of context
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize" }
opt.shiftround = true -- Round indent
opt.shiftwidth = 2 -- Size of an indent
opt.shortmess:append({ W = true, I = true, c = true })
opt.showmode = false -- Dont show mode since we have a statusline
opt.sidescrolloff = 8 -- Columns of context
opt.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
opt.smartcase = true -- Don't ignore case with capitals
opt.smartindent = true -- Insert indents automatically
opt.splitbelow = true -- Put new windows below current
opt.splitright = true -- Put new windows right of current
opt.tabstop = 2 -- Number of spaces tabs count for
opt.termguicolors = true -- True color support
opt.timeoutlen = 300
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200 -- Save swap file and trigger CursorHold
opt.wildmode = "longest:full,full" -- Command-line completion mode
opt.winminwidth = 5 -- Minimum window width
opt.wrap = false -- Disable line wrap

-- more risky, but cleaner
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

if vim.fn.has("nvim-0.9.0") == 1 then
  opt.splitkeep = "screen"
  opt.shortmess:append({ C = true })
end

-- dictionary
opt.spelllang = { "en", "pt_pt" }
opt.encoding = "utf-8"

-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0

------------------------------------------------
-- OLD OPTIONS
------------------------------------------------

-- vim.opt.tw = 79
-- vim.opt.fo = "cq"
-- vim.opt.wm = 0
-- vim.opt.tabstop = 2
-- vim.opt.softtabstop = -1
-- vim.opt.shiftwidth = 0
-- vim.opt.shiftround = true
-- vim.opt.expandtab = true
-- vim.opt.autoindent = true
--
-- vim.opt.relativenumber = true
--
-- vim.opt.autoread = true
-- vim.opt.autowriteall = true
-- vim.opt.number = true
-- vim.opt.ruler = true
-- vim.opt.showmode = true
--
-- vim.opt.termguicolors = true
--
-- vim.opt.cmdheight = 1
-- vim.opt.showcmd = true
-- vim.opt.laststatus = 2
-- vim.opt.cursorline = true
--
-- -- experimentation for performance
-- vim.opt.lazyredraw = true
-- vim.opt.synmaxcol = 200
-- vim.opt.ttyfast = true
-- vim.opt.updatetime = 100
--
-- vim.opt.numberwidth = 1
-- vim.opt.fixendofline = false
-- vim.opt.foldmethod = "manual"
-- vim.opt.showmatch = true
-- -- vim.opt.ignorecase = true
-- -- vim.opt.smartcase = true
--
-- vim.opt.completeopt = "menuone,noinsert,noselect"
--
-- vim.opt.shortmess = "aoOtTI"
-- vim.opt.hidden = true
-- vim.opt.history = 1000
-- vim.opt.updatetime = 100
--
-- -- highlight search hits
-- vim.opt.hlsearch = true
-- vim.opt.incsearch = true
-- vim.opt.linebreak = true
-- vim.opt.wrap = false
--
-- -- more risky, but cleaner
-- vim.opt.backup = false
-- vim.opt.writebackup = false
-- vim.opt.swapfile = false
--
-- vim.opt.completeopt = "menuone,noinsert,noselect"
-- vim.opt.complete = vim.opt.complete + "kspell"
-- vim.opt.shortmess = vim.opt.shortmess + "c"
-- vim.opt.mouse = "a"
--
