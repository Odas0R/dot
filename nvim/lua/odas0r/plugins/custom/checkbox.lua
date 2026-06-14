return {
  "odas0r/checkbox.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/odas0r/features/checkbox",
  keys = {
    { "<leader>x", mode = { "n", "v" }, desc = "Toggle checkbox" },
  },
  config = function(_, opts)
    require("odas0r.features.checkbox").setup(opts)
  end,
}
