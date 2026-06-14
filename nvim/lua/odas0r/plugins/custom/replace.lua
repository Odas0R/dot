return {
  "odas0r/replace.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/odas0r/features/replace",
  cmd = "Replace",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function(_, opts)
    require("odas0r.features.replace").setup(opts)
  end,
}
