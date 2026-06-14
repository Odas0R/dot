return {
  "odas0r/terminal.nvim",
  dir = "~/github.com/odas0r/dot/nvim/lua/odas0r/features/terminal",
  cmd = { "Term", "T" },
  keys = {
    { "<leader>t", mode = { "n", "t" }, desc = "Toggle Terminal" },
  },
  opts = {
    -- Override defaults if needed
    -- toggle_keymap = "<leader>t",
    -- esc_to_exit = true,
    -- close_on_nav = true,
  },
  config = function(_, opts)
    require("odas0r.features.terminal").setup(opts)
  end,
}
