return {
  "ellisonleao/gruvbox.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    -- 1. Load the module directly
    local gruvbox = require("gruvbox")

    -- 2. Access the palette and default config
    local palette = gruvbox.palette
    local config = gruvbox.config

    gruvbox.setup({
      terminal_colors = true,
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
      inverse = true,
      contrast = "",
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
        ["@markup.strong"] = {
          bold = config.bold,
          fg = palette.bright_yellow,
        },
        ["@markup.italic"] = {
          italic = config.italic.emphasis,
          fg = palette.bright_purple,
        },
        ["@lsp.type.class.markdown"] = {
          bold = config.bold,
          fg = palette.bright_orange,
        },
      },
      dim_inactive = false,
      transparent_mode = false,
    })

    vim.cmd("colorscheme gruvbox")
    vim.o.background = "dark"
    vim.o.termguicolors = true
  end,
}
