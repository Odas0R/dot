return {
  "odas0r/terminal.nvim",
  dir = "~/github.com/odas0r/dot/nvim/lua/odas0r/features/terminal",
  cmd = { "Term", "T" },
  keys = {
    { "<leader>t", mode = { "n", "t" }, desc = "Toggle Terminal" },
  },
  opts = {
    -- Keep terminal windows open until explicitly toggled/closed.
    -- This prevents scripts/commands that trigger buffer/window events or return
    -- non-zero statuses from making the terminal disappear unexpectedly.
    close_on_nav = false,
  },
  config = function(_, opts)
    require("odas0r.features.terminal").setup(opts)
  end,
}
