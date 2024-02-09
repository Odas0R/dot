local M = {}

M.init = function()
  -- Fix for autotag
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    underline = true,
    virtual_text = {
      spacing = 5,
      severity_limit = "Warning",
    },
    update_in_insert = true,
  })

  ------------------------------------
  -- Custom Files
  ------------------------------------
  vim.filetype.add({
    extension = {
      mdx = "mdx",
    },
  })
  local lang = require("vim.treesitter.language")
  lang.register("markdown", "mdx")
end

M.config = function()
  require("nvim-treesitter.configs").setup({
    highlight = {
      enable = true,
    },
    indent = { enable = false },
    ensure_installed = {
      "bash",
      "c",
      "go",
      "html",
      "javascript",
      "json",
      "lua",
      "luadoc",
      "luap",
      "dart",
      "markdown",
      "markdown_inline",
      "python",
      "query",
      "regex",
      "tsx",
      "typescript",
      "vim",
      "vimdoc",
      "yaml",
    },

    -- Plugins
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-Space>",
        node_incremental = "<C-Space>",
        scope_incremental = false,
        node_decremental = "<bs>",
      },
    },
    autotag = { enable = true },
    refactor = {
      highlight_definitions = { enable = true },
    },

    -- disable slow treesitter highlight for large files
    -- https://github.com/nvim-treesitter/nvim-treesitter
    -- disable = function(lang, buf)
    --   local max_filesize = 100 * 1024 -- 100 KB
    --   local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
    --   if ok and stats and stats.size > max_filesize then
    --     return true
    --   end
    -- end,
  })

  -- nvim-ts-context-commentstring integration with Comment.nvim
  -- https://github.com/JoosepAlviste/nvim-ts-context-commentstring#commentnvim
  require("ts_context_commentstring").setup({
    enable_autocmd = false,
    languages = {
      typescript = "// %s",
    },
  })
end

return M
