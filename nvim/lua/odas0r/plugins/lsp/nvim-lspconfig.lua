return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    require("odas0r.lsp.patches").setup()
    require("odas0r.lsp.attach").setup()
    require("odas0r.lsp.capabilities").setup()

    vim.lsp.enable(require("odas0r.lsp.servers"))
  end,
}
