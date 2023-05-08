-----------------------------------------
-- Lazy package manager installer
-----------------------------------------

-- Interesting videos & articles
--
-- https://www.youtube.com/watch?v=2ahI8lYUYgw
-- https://neovim.io/doc/user/lua-guide.html#lua-guide

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
  -- Theme Tokyonight
  -- {
  --   "folke/tokyonight.nvim",
  --   priority = 1000,
  --   config = function()
  --     require("tokyonight").setup({
  --       -- use the night style
  --       style = "night",
  --       transparent = true, -- Enable this to disable setting the background color
  --       terminal_colors = true, -- Configure the colors used when opening a `:terminal` in Neovim
  --       -- Style to be applied to different syntax groups
  --       -- Value is any valid attr-list value for `:help nvim_set_hl`
  --       comments = { italic = true },
  --       keywords = { italic = true },
  --       functions = {
  --         bold = true,
  --       },
  --       -- Change the "hint" color to the "orange" color, and make the "error" color bright red
  --       on_colors = function(colors)
  --         colors.error = "#ff0000"
  --       end,
  --     })
  --
  --     vim.cmd.colorscheme("tokyonight")
  --   end,
  -- },

  {
    "ellisonleao/gruvbox.nvim",
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
          Identifier = { link = "GruvboxFg" },
        },
        dim_inactive = false,
        transparent_mode = false,
      })
      vim.cmd("colorscheme gruvbox")
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
  install = { colorscheme = { "tokyonight" } },
})

-- import local plugins
require("odas0r")
