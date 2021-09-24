-- Eslint Setup with efm
-- https://github.com/neovim/nvim-lspconfig/wiki/User-contributed-tips#eslint_d
local eslint = {
  lintCommand = "eslint_d -f unix --stdin --stdin-filename ${INPUT}",
  lintStdin = true,
  lintFormats = { "%f:%l:%c: %m" },
  lintIgnoreExitCode = true,
}

-- local shellcheck = {
--   lintCommand = "shellcheck -f gcc -x",
--   lintSource = "shellcheck",
--   lintFormats = {
--     "%f:%l:%c: %trror: %m",
--     "%f:%l:%c: %tarning: %m",
--     "%f:%l:%c: %tote: %m",
--   },
-- }

local util = require("lspconfig").util

require("lspconfig").efm.setup({
  init_options = { documentFormatting = false },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "sh" },
  root_dir = function(fname)
    return util.root_pattern("tsconfig.json")(fname) or util.root_pattern(".eslintrc.js", ".git")(fname)
  end,
  settings = {
    rootMarkers = { ".eslintrc.js", ".git/" },
    languages = {
      -- sh = { shellcheck },
      javascript = { eslint },
      javascriptreact = { eslint },
      typescript = { eslint },
      typescriptreact = { eslint },
    },
  },
})
