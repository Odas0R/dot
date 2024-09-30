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

end

M.config = function()
  -- defer until after first render to improve startup time of 'nvim {filename}'
  vim.defer_fn(function()
    require("nvim-treesitter.configs").setup({
      highlight = {
        enable = true,
        disable = {
          -- "markdown"
          "dockerfile",
        },
        additional_vim_regex_highlighting = true,
      },
      indent = { enable = false },
      ensure_installed = {
        "bash",
        "c",
        "go",
        "gotmpl",
        "templ",
        "html",
        "javascript",
        "json",
        "css",
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
        "sql",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
        "astro",
      },

      -- Plugins
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
  end, 0)
end

return M
