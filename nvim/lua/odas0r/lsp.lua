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
  buf_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  buf_set_keymap("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  buf_set_keymap("n", "K", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap("n", "J", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)

  buf_set_keymap("n", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  buf_set_keymap("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
end

local capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities())

local debounce_text_changes = 150

-- npm install -g typescript typescript-language-server
require("lspconfig").tsserver.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#java_language_server
-- https://github.com/georgewfraser/java-language-server
local home = os.getenv("HOME")
require("lspconfig").java_language_server.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
  cmd = { home .. "/tools/javalsp/dist/lang_server_mac.sh" },
  root_dir = function(fname)
    return require("lspconfig").util.root_pattern("pom.xml", "gradle.build", ".classpath", ".git")(fname)
      or vim.fn.getcwd()
  end,
})

-- require("lspconfig").jdtls.setup({
--   on_attach = on_attach,
--   cmd = { "jdtls" },
--   root_dir = function(fname)
--     return require("lspconfig").util.root_pattern("pom.xml", "gradle.build", ".git")(fname) or vim.fn.getcwd()
--   end,
-- })

-- npm i -g vscode-langservers-extracted
require("lspconfig").cssls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- npm i -g yaml-language-server
require("lspconfig").yamlls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- npm i -g bash-language-server
require("lspconfig").bashls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

--  npm install -g @tailwindcss/language-server
require("lspconfig").tailwindcss.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- pip install 'python-lsp-server[all]'
require("lspconfig").pylsp.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
})

-- ./dot/installs/golang
require("lspconfig").gopls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
  cmd = { "gopls", "serve" },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
})

-- npm i -g stylelint-lsp
-- require("lspconfig").stylelint_lsp.setup({
--   on_attach = on_attach,
--   capabilities = capabilities,
-- })

-- LSP for lua
-- https://github.com/sumneko/lua-language-server/wiki/Build-and-Run-(Standalone)
-- https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#sumneko_lua
local sumneko_binary_path = vim.fn.exepath("lua-language-server")
local sumneko_root_path = vim.fn.fnamemodify(sumneko_binary_path, ":h:h:h")

local runtime_path = vim.split(package.path, ";")
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

require("lspconfig").sumneko_lua.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes,
  },
  cmd = { sumneko_binary_path, "-E", sumneko_root_path .. "/main.lua" },
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
