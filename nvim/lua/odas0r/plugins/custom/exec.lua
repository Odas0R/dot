return {
  "odas0r/exec.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/odas0r/features/exec",
  ft = { "sh", "bash", "sql", "lua" },
  config = function(_, opts)
    require("odas0r.features.exec").setup(opts)
  end,
}
