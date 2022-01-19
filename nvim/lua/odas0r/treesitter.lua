require("nvim-treesitter.configs").setup({
  ensure_installed = "maintained",

  indent = { enable = true },

  highlight = {
    enable = true,

    disable = { "vim" },

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = { "markdown" },
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
