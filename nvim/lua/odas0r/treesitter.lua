require("nvim-treesitter.configs").setup({
  ensure_installed = "all",

  indent = { enable = true },

  highlight = {
    enable = true,
    disable = { "html" },

  },

  -- Plugins
  incremental_selection = { enable = true },

  autotag = { enable = true },
  refactor = {
    highlight_definitions = { enable = true },
  },
})

-- Fix for autotag
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  underline = true,
  virtual_text = {
    spacing = 5,
    severity_limit = "Warning",
  },
  update_in_insert = true,
})
