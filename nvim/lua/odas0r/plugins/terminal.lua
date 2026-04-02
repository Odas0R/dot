local Util = require("odas0r.utils")

return {
  "odas0r/terminal.nvim",
  dir = "~/github.com/odas0r/dot/nvim/lua/odas0r/internal/terminal",
  opts = {
    -- Override defaults if needed
    -- toggle_keymap = "<leader>t",
    -- esc_to_exit = true,
    -- close_on_nav = true,
  },
  config = function(_, opts)
    require("odas0r.internal.terminal").setup(opts)
  end,
}
