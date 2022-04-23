-- go install github.com/mattn/efm-langserver@latest

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
  buf_set_keymap("n", "K", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap("n", "J", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
end

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

local debounce_text_changes = 150

require("lspconfig").efm.setup({
  on_attach = on_attach,
  flags = {
    debounce_text_changes,
  },
  init_options = { documentFormatting = false },
  filetypes = { "sh" },
  root_dir = function(fname)
    return util.root_pattern(".git")(fname) or ""
  end,
  settings = {
    rootMarkers = { ".git/" },
    languages = {
      sh = { shellcheck },
    },
  },
})
