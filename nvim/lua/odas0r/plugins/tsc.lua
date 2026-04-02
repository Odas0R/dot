return {
  "dmmulroy/tsc.nvim",
  cmd = { "TSC" },
  init = function()
    require("tsc").setup({})
  end,
}
