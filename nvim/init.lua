-----------------------------------------
-- Lazy package manager installer
-----------------------------------------

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
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
-- Leader
-----------------------------------------

vim.g.mapleader = ","

-----------------------------------------
-- Configs
-----------------------------------------

local keymap = vim.keymap.set

-- https://github.com/folke/lazy.nvim#-plugin-spec
require("lazy").setup({

  -- Theme Gruvbox
  {
    "ellisonleao/gruvbox.nvim", -- theme
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "dark",
        overrides = {
          Comment = { italic = true },
          HarpoonWindow = { bg = "#282828" },
          HarpoonBorder = { bg = "#282828" },
          -- Example: https://github.com/mhinz/vim-signify/blob/master/doc/signify.txt#L597
          SignColumn = { bg = "#282828" },
          TermCursorNC = { bg = "#cc241d", fg = "#ffffff" },

          -- markdown
          markdownH1 = { link = "GruvboxYellowBold", bold = true },
          markdownH2 = { link = "GruvboxYellowBold", bold = true },
        },
      })
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" }, -- :TSInstallFromGrammar
  {
    "nvim-treesitter/playground",
    lazy = true,
    cmd = "TSPlaygroundToggle",
  },

  -- Status Bar
  { "nvim-lualine/lualine.nvim", dependencies = {
    "nvim-lua/lsp-status.nvim",
  } },

  -- Telescope
  { "nvim-telescope/telescope.nvim", tag = "0.1.1" },
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },

  -- Git, Source Control
  { "mhinz/vim-signify" },

  -- General
  { "nvim-lua/plenary.nvim" },
  { "wakatime/vim-wakatime" },
  { "ThePrimeagen/harpoon" },
  { "windwp/nvim-ts-autotag" },
  { "jose-elias-alvarez/typescript.nvim" },
  { "s1n7ax/nvim-terminal" }, -- terminal
  { "numToStr/Comment.nvim" }, -- comment
  { "JoosepAlviste/nvim-ts-context-commentstring" }, -- use TS for comment.nvim
  {
    "github/copilot.vim",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      vim.g.copilot_node_command = "/home/odas0r/.nvm/versions/node/v16.19.1/bin/node"
      keymap({ "i", "n" }, "<leader>j", "<Plug>(copilot-previous)", { silent = true })
      keymap({ "i", "n" }, "<leader>k", "<Plug>(copilot-next)", { silent = true })
    end,
  },
  {
    "nmac427/guess-indent.nvim",
    config = function()
      require("guess-indent").setup({
        auto_cmd = true, -- Set to false to disable automatic execution
        filetype_exclude = { -- A list of filetypes for which the auto command gets disabled
          "netrw",
          "defx",
          "tutor",
        },
        buftype_exclude = { -- A list of buffer types for which the auto command gets disabled
          "help",
          "nofile",
          "terminal",
          "prompt",
        },
      })
    end,
  },

  -- File Explorer
  {
    "Shougo/defx.nvim",
    build = ":UpdateRemotePlugins",
    dependencies = { "kristijanhusak/defx-git" },
  },

  -- database
  { "tpope/vim-dadbod" },
  { "kristijanhusak/vim-dadbod-completion" },

  -- lsp, Completion Engine
  { "neovim/nvim-lspconfig" },
  { "onsails/lspkind-nvim" },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "quangnguyen30192/cmp-nvim-ultisnips",
    },
  },

  -- formatter
  { "mhartington/formatter.nvim" },

  -- snippet Engine
  { "sirver/UltiSnips" },

  -- " writing
  -- { "preservim/vim-markdown" },
}, {
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
require("plenary.reload").reload_module("odas0r", true)
