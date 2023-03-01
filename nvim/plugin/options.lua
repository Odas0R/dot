-----------------------------------------
-- Options
-----------------------------------------

vim.opt.background = "dark"
vim.opt.tw = 79
vim.opt.fo = "cq"
vim.opt.wm = 0
vim.opt.tabstop = 2
vim.opt.softtabstop = -1
vim.opt.shiftwidth = 0
vim.opt.shiftround = true
vim.opt.expandtab = true
vim.opt.autoindent = true

vim.opt.relativenumber = true

vim.opt.autoread = true
vim.opt.autowriteall = true
vim.opt.number = true
vim.opt.ruler = true
vim.opt.showmode = true

vim.opt.termguicolors = true

vim.opt.cmdheight = 1
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.cursorline = true

-- experimentation for performance
vim.opt.lazyredraw = true
vim.opt.synmaxcol = 200
vim.opt.ttyfast = true
vim.opt.updatetime = 100

vim.opt.numberwidth = 2
vim.opt.fixendofline = false
vim.opt.foldmethod = "manual"
vim.opt.showmatch = true
-- vim.opt.ignorecase = true
-- vim.opt.smartcase = true

vim.opt.completeopt = "menuone,noinsert,noselect"

vim.opt.shortmess = "aoOtTI"
vim.opt.hidden = true
vim.opt.history = 1000
vim.opt.updatetime = 100

-- highlight search hits
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.linebreak = true
vim.opt.wrap = false

-- more risky, but cleaner
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.complete = vim.opt.complete + "kspell"
vim.opt.shortmess = vim.opt.shortmess + "c"
vim.opt.mouse = "a"

-- dictionary
vim.opt.spelllang = vim.opt.spelllang + "pt_pt"
vim.opt.encoding = "utf-8"

vim.opt.path = vim.opt.path + "**"
vim.opt.wildmenu = true
vim.opt.wildignore = {
  "**/node_modules/**",
  "*_build/*",
  "*formatting*/*",
  "**/coverage/*",
  "**/node_modules/*",
  "**/android/*",
  "**/ios/*",
  "**/.git/*",
}
vim.opt.wildignorecase = true
vim.opt.wildmode = "longest:full,full"

vim.opt.clipboard = "unnamed,unnamedplus"
