local on_attach = function(_, bufnr)
  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end
  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

  -- Mappings.
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap("n", "J", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap("n", "K", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
end

-- Eslint Setup with efm
-- https://github.com/neovim/nvim-lspconfig/wiki/User-contributed-tips#eslint_d
local eslint = {
  lintCommand = "eslint_d -f unix --stdin --stdin-filename ${INPUT}",
  lintStdin = true,
  lintFormats = { "%f:%l:%c: %m" },
  lintIgnoreExitCode = true,
}

local shellcheck = {
  lintCommand = "shellcheck -f gcc -x",
  lintSource = "shellcheck",
  lintFormats = {
    "%f:%l:%c: %trror: %m",
    "%f:%l:%c: %tarning: %m",
    "%f:%l:%c: %tote: %m",
  },
}

local util = require("lspconfig").util

require("lspconfig").efm.setup({
  on_attach = on_attach,
  init_options = { documentFormatting = false },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "sh" },
  root_dir = function(fname)
    return util.root_pattern("tsconfig.json")(fname) or util.root_pattern(".eslintrc.js", ".git")(fname)
  end,
  settings = {
    rootMarkers = { ".eslintrc.js", ".git/" },
    languages = {
      sh = { shellcheck },
      javascript = { eslint },
      javascriptreact = { eslint },
      typescript = { eslint },
      typescriptreact = { eslint },
    },
  },
})
