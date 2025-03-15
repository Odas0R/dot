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
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

-----------------------------------------
-- Configs
-----------------------------------------

vim.g.mapleader = ","

-- custom filetypes
vim.filetype.add({ extension = { templ = "templ" } })

-- https://github.com/folke/lazy.nvim#-plugin-spec
require("lazy").setup({
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local Gruvbox = require("odas0r.gruvbox")

      local colors = Gruvbox.colors()
      local config = Gruvbox.config()

      require("gruvbox").setup({
        terminal_colors = true, -- add neovim terminal colors
        undercurl = true,
        underline = true,
        bold = true,
        italic = {
          strings = true,
          emphasis = true,
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
          -- https://github.com/ellisonleao/gruvbox.nvim/blob/main/lua/gruvbox.lua
          -- Identifiers should be white for better readibility, but not too
          -- bright, the blue is terrible.
          Identifier = { link = "GruvboxFg1" },
          ["@text"] = { link = "GruvboxFg1" },

          -- Markdown custom syntax
          --
          -- If you want to change the color of the syntax, you can use the
          -- `:Inspect` command to see the current syntax group and then change
          -- it with the overrides table
          ["@markup.strong"] = { bold = config.bold, fg = colors.yellow },
          ["@markup.italic"] = {
            italic = config.italic.emphasis,
            fg = colors.purple,
          },
          ["@lsp.type.class.markdown"] = { bold = config.bold, fg = colors.orange },

          -- Fix the colors for the floating windows
          FloatBorder = { fg = colors.fg1 },
          FloatTitle = { fg = colors.fg1 },
        },
        dim_inactive = false,
        transparent_mode = false,
      })
      vim.cmd("colorscheme gruvbox")
      vim.o.background = "dark" -- or "light" for light mode
      -- vim.o.background = "light" -- or "light" for light mode
      vim.o.termguicolors = true
    end,
  },
  -- Treesitter
  -- https://github.com/nvim-treesitter/nvim-treesitter/#adding-queries
  -- https://github.com/JoosepAlviste/nvim-ts-context-commentstring
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdateSync" },
    init = require("odas0r.plugin.treesitter").init,
    config = require("odas0r.plugin.treesitter").config,
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
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },

  -- Git, Source Control
  {
    "mhinz/vim-signify",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
      vim.g.signify_disable_by_default = 0

      Utils.map({ "n", "i" }, "<leader>gj", "<Plug>(signify-next-hunk)<cmd>SignifyHunkDiff<CR>")
      Utils.map({ "n", "i" }, "<leader>gk", "<Plug>(signify-prev-hunk)<cmd>SignifyHunkDiff<CR>")
      Utils.map({ "n", "i" }, "<leader>gh", "<cmd>SignifyHunkDiff<CR>")

      Utils.map({ "n", "i" }, "<leader>gu", "<cmd>SignifyHunkUndo<cr>")
      Utils.map({ "n", "i" }, "<leader>gt", "<cmd>SignifyToggle<cr>")

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
  {
    "ThePrimeagen/harpoon",
    init = function()
      require("odas0r.plugin.harpoon").init()
    end,
    config = function()
      require("odas0r.plugin.harpoon").config()
    end,
  },
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          hide_during_completion = true,
          debounce = 50,
          keymap = {
            accept = "<C-e>",
            accept_word = false,
            accept_line = false,
            next = "<leader>j",
            prev = "<leader>k",
            dismiss = "<C-c>",
          },
        },
        filetypes = {
          ["*"] = true,
          sh = function()
            -- disable for .env files
            if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "^%.env.*") then
              return false
            end
            return true
          end,
        },
      })
    end,
  },
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
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup({
        lsp_inlay_hints = {
          enable = false,
        },
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
  },
  -- File Explorer
  {
    "Shougo/defx.nvim",
    build = ":UpdateRemotePlugins",
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
  {
    "L3MON4D3/LuaSnip",
    -- follow latest release.
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
    init = require("odas0r.plugin.luasnip").init,
    config = require("odas0r.plugin.luasnip").config,
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
      "saadparwaiz1/cmp_luasnip",
    },
    init = require("odas0r.plugin.nvim-cmp").init,
    config = require("odas0r.plugin.nvim-cmp").config,
  },
  {
    "mhartington/formatter.nvim",
    cmd = "FormatWrite",
    init = require("odas0r.plugin.formatter").init,
    config = require("odas0r.plugin.formatter").config,
  },

  -- == Local Plugins ==
  --
  --
  -- odas0r:
  --
  -- Apperantly the dir = ".." is not working as intended. It is not injecting
  -- the terminal module into the lazy.nvim plugin system, so for now we hack it
  -- and just inject the module.
  --
  --
  vim.tbl_extend("force", {
    "odas0r/terminal.nvim",
    dir = "~/github.com/odas0r/dot/nvim/lua/odas0r/plugin/terminal",
  }, require("odas0r.plugin.terminal")),
}, {
  -- dev = {
  --   path = os.getenv("HOME") .. "/github.com/odas0r/dot/nvim/lua/odas0r/plugin",
  -- },
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
