return {
  "odas0r/refactor.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/odas0r/features/refactor",
  keys = {
    { "<C-n>", mode = "v", desc = "Extract selection to new file" },
  },
  config = function(_, opts)
    require("odas0r.features.refactor").setup(opts)
  end,
}
