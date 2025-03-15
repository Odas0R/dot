return {
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
}
