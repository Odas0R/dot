local Utils = require("odas0r.utils")

vim.python3_host_prog = "/usr/bin/python3"

-----------------------------------------
-- Lazy package manager installer
-----------------------------------------

-- Interesting videos & articles
--
-- https://www.youtube.com/watch?v=2ahI8lYUYgw
-- https://neovim.io/doc/user/lua-guide.html#lua-guide

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-----------------------------------------
-- Configs
-----------------------------------------

vim.g.mapleader = ","

-- https://github.com/folke/lazy.nvim#-plugin-spec
require("lazy").setup({
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        undercurl = true,
        underline = true,
        bold = true,
        italic = {
          strings = true,
          comments = true,
          operators = false,
          folds = true,
        },
        strikethrough = true,
        invert_selection = false,
        invert_signs = false,
        invert_tabline = false,
        invert_intend_guides = false,
        inverse = true, -- invert background for search, diffs, statuslines and errors
        contrast = "", -- can be "hard", "soft" or empty string
        palette_overrides = {},
        overrides = {
          -- https://github.com/ellisonleao/gruvbox.nvim/blob/main/lua/gruvbox/groups.lua
          -- Identifiers should be white for better readibility, but not too
          -- bright, the blue is terrible.
          Identifier = { link = "GruvboxFg1" },
        },
        dim_inactive = false,
        transparent_mode = false,
      })
      vim.cmd("colorscheme gruvbox")
      vim.o.background = "dark" -- or "light" for light mode
    end,
  },

  -- Treesitter
  -- https://github.com/nvim-treesitter/nvim-treesitter/#adding-queries
  -- https://github.com/JoosepAlviste/nvim-ts-context-commentstring
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdateSync" },
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    init = require("odas0r.plugin.treesitter").init,
    config = require("odas0r.plugin.treesitter").config,
  },
  -- I disabled autoident from treesitter since it stopped working on dart,
  -- this is a fix for it:
  {
    "nvim-treesitter/playground",
    cmd = "TSPlaygroundToggle",
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-lua/lsp-status.nvim",
    },
    event = "VeryLazy",
    config = require("odas0r.plugin.lualine").config,
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.2",
    lazy = false,
    init = require("odas0r.plugin.telescope").init,
    config = require("odas0r.plugin.telescope").config,
  },
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },

  -- Git, Source Control
  {
    "mhinz/vim-signify",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
      vim.g.signify_disable_by_default = 0

      Utils.map({ "n", "i" }, "<leader>gj", "<Plug>(signify-next-hunk)<cmd>SignifyHunkDiff<CR>", { silent = true })
      Utils.map({ "n", "i" }, "<leader>gk", "<Plug>(signify-prev-hunk)<cmd>SignifyHunkDiff<CR>", { silent = true })
      Utils.map({ "n", "i" }, "<leader>gh", "<cmd>SignifyHunkDiff<CR>", { silent = true })

      Utils.map({ "n", "i" }, "<leader>gu", "<cmd>SignifyHunkUndo<cr>", { silent = true })
      Utils.map({ "n", "i" }, "<leader>gt", "<cmd>SignifyToggle<cr>", { silent = true })

      vim.cmd([[
function! s:show_current_hunk() abort
  let h = sy#util#get_hunk_stats()
  if !empty(h)
    echo printf('[Hunk %d/%d]', h.current_hunk, h.total_hunks)
  endif
endfunction

augroup ConfigSignifyHunk
  autocmd!
  autocmd User SignifyHunk call s:show_current_hunk()
augroup END
]])
    end,
  },

  -- General
  { "nvim-lua/plenary.nvim" },
  { "wakatime/vim-wakatime", event = "VeryLazy" },
  {
    "ThePrimeagen/harpoon",
    init = function()
      require("odas0r.plugin.harpoon").init()
    end,
    config = function()
      require("odas0r.plugin.harpoon").config()
    end,
  },
  { "windwp/nvim-ts-autotag", event = "InsertEnter" },
  { "jose-elias-alvarez/typescript.nvim", event = { "BufReadPre", "BufNewFile" } },
  {
    "dmmulroy/tsc.nvim",
    cmd = { "TSC" },
    init = function()
      require("tsc").setup({
        -- TO MAKE IT WORK FOR MONOREPOS
        -- flags = {
        --   build = true,
        -- },
      })
    end,
  },

  {
    "s1n7ax/nvim-terminal",
    keys = require("odas0r.plugin.nvim-terminal").keys(),
    init = require("odas0r.plugin.nvim-terminal").init,
    config = require("odas0r.plugin.nvim-terminal").config,
  },
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gc", mode = "v", desc = "Comment visual" },
      { "gcc", mode = "n", desc = "Comment one line" },
    },
    config = require("odas0r.plugin.comment").config,
  }, -- comment
  {
    "github/copilot.vim",
    cmd = "Copilot",
    event = "InsertEnter",
    init = function()
      vim.g.copilot_node_command = "/home/odas0r/.nvm/versions/node/v16.19.1/bin/node"
      vim.g.copilot_filetypes = {
        ["*"] = false,
        ["javascript"] = true,
        ["javascriptreact"] = true,
        ["typescript"] = true,
        ["typescriptreact"] = true,
        ["vue"] = true,
        ["lua"] = true,
        ["html"] = true,
        ["sql"] = true,
        ["sh"] = true,
        ["bash"] = true,
        ["go"] = true,
        ["java"] = true,
        ["json"] = true,
        ["jsonc"] = true,
        ["make"] = true,
        ["astro"] = true,
        ["dart"] = true,
        ["css"] = true,
        ["toml"] = true,
        ["scss"] = true,
        ["config"] = true,
      }

      Utils.map({ "i", "n" }, "<leader>j", "<Plug>(copilot-previous)", { silent = true, noremap = true })
      Utils.map({ "i", "n" }, "<leader>k", "<Plug>(copilot-next)", { silent = true, noremap = true })
    end,
  },
  {
    "nmac427/guess-indent.nvim",
    config = function()
      require("odas0r.plugin.guess-indent").config()
    end,
  },

  -- File Explorer
  {
    "Shougo/defx.nvim",
    build = ":UpdateRemotePlugins",
  },

  -- database
  {
    "tpope/vim-dadbod",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
      vim.g.db = "postgres://postgres:postgres@localhost:5432/postgres"
      vim.g.completion_matching_ignore_case = 1
    end,
  },

  -- lsp, Completion Engine
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
      require("odas0r.plugin.lsp").init()
    end,
    config = function()
      require("odas0r.plugin.lsp").config()
    end,
  },
  { "onsails/lspkind-nvim", event = { "BufReadPre", "BufNewFile" } },
  -- Completion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "quangnguyen30192/cmp-nvim-ultisnips",
      "kristijanhusak/vim-dadbod-completion",
      {
        "odas0r/cmp-zet",
        dev = true,
        config = require("odas0r.cmp-zet").setup,
        dependencies = { "nvim-lua/plenary.nvim" },
      },
    },
    init = require("odas0r.plugin.nvim-cmp").init,
    config = require("odas0r.plugin.nvim-cmp").config,
  },
  {
    "dawsers/edit-code-block.nvim",
    config = function()
      require("ecb").setup({
        wincmd = "split", -- this is the default way to open the code block window
      })
    end,
  },
  { "sirver/UltiSnips", event = { "BufReadPre", "BufNewFile" } },
  {
    "mhartington/formatter.nvim",
    cmd = "FormatWrite",
    init = function()
      require("odas0r.plugin.formatter").init()
    end,
    config = function()
      require("odas0r.plugin.formatter").config()
    end,
  },
}, {
  dev = {
    path = "/home/odas0r/github.com/odas0r/dot/nvim/lua/odas0r",
  },
  default = {
    lazy = true,
  },
  performance = {
    rtp = {
      disabled_plugins = { -- disable some rtp plugins
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  install = { colorscheme = { "gruvbox" } },
})

-- import local plugins
require("odas0r")

vim.cmd([[
  syntax include @HTML syntax/html.vim
  syntax include @TypeScript syntax/typescript.vim
  syntax region scriptTag start=+<script\>+ end=+</script>+ contains=@TypeScript
]])
