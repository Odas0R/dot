require("nvim-treesitter.configs").setup({
  ensure_installed = "all",

  indent = { enable = true },

  highlight = {
    enable = true,
    disable = { "sql" },
  },

  -- Plugins
  incremental_selection = {
    enable = true,
    init_selection = "gnn", -- set to `false` to disable one of the mappings
  },
  autotag = { enable = true },
  refactor = {
    highlight_definitions = { enable = true },
  },

  -- nvim-ts-context-commentstring integration with Comment.nvim
  -- https://github.com/JoosepAlviste/nvim-ts-context-commentstring#commentnvim
  context_commentstring = {
    enable = true,
    enable_autocmd = false,
  },

  -- disable slow treesitter highlight for large files
  -- https://github.com/nvim-treesitter/nvim-treesitter
  disable = function(lang, buf)
    local max_filesize = 100 * 1024 -- 100 KB
    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
    if ok and stats and stats.size > max_filesize then
      return true
    end
  end,
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
