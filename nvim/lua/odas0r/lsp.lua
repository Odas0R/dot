local lsp_keymaps = function(_, bufnr)
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

  buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  buf_set_keymap("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  buf_set_keymap("n", "K", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap("n", "J", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)

  buf_set_keymap("n", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  buf_set_keymap("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
end

local capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities())

local util = require("lspconfig").util

local debounce_text_changes = 150

-- npm install -g typescript typescript-language-server
require("typescript").setup({
  debug = false,
  server = {
    on_attach = lsp_keymaps,
    capabilities = capabilities,
    flags = {
      debounce_text_changes,
    },
  },
})

-- npm install -g @astrojs/language-server
require("lspconfig").astro.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- npm i -g vscode-langservers-extracted
require("lspconfig").eslint.setup({})

require("lspconfig").denols.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  root_dir = util.root_pattern("deno.json"),
  init_options = {
    lint = true,
  },
})

-- npm i -g vscode-langservers-extracted
require("lspconfig").cssls.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
  settings = {
    scss = {
      lint = {
        unknownAtRules = "ignore",
      },
    },
    css = {
      lint = {
        unknownAtRules = "ignore",
      },
    },
  },
})

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#hls
require("lspconfig").hls.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- npm i -g yaml-language-server
require("lspconfig").yamlls.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
  settings = {
    schemas = {
      ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
    },
  },
})

-- npm i -g bash-language-server
require("lspconfig").bashls.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

--  npm install -g @tailwindcss/language-server
require("lspconfig").tailwindcss.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 700,
  },
})

-- pip install 'python-lsp-server[all]'
require("lspconfig").pylsp.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- go install golang.org/x/tools/gopls@latest
-- go install golang.org/x/tools/cmd/goimports@latest
require("lspconfig").gopls.setup({
  cmd = { "gopls", "serve" },
  filetypes = { "go", "gomod" },
  root_dir = util.root_pattern("go.work", "go.mod", ".git"),
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- npm i -g stylelint-lsp
-- require("lspconfig").stylelint_lsp.setup({
--   on_attach = on_attach,
--   capabilities = capabilities,
--   flags = {
--     debounce_text_changes,
--   },
--   filetypes = { "css", "less", "scss" },
-- })

-- LSP for lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#sumneko_lua
local sumneko_binary_path = vim.fn.exepath("lua-language-server")
local sumneko_root_path = vim.fn.fnamemodify(sumneko_binary_path, ":h:h:h")

local runtime_path = vim.split(package.path, ";")
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

require("lspconfig").sumneko_lua.setup({
  on_attach = lsp_keymaps,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
  cmd = { sumneko_binary_path, "-E", sumneko_root_path .. "/lua-language-server/main.lua" },
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = "LuaJIT",
        -- Setup your lua path
        path = runtime_path,
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { "vim" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
    },
  },
})
