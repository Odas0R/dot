local buf_set_keymap = function(bufnr, ...)
  vim.api.nvim_buf_set_keymap(bufnr, ...)
end

local buf_set_option = function(bufnr, ...)
  vim.api.nvim_buf_set_option(bufnr, ...)
end

local on_attach = function(_, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

  -- Mappings.
  local opts = { noremap = true, silent = true }

  buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  buf_set_keymap(bufnr, "n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap(bufnr, "n", "gk", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap(bufnr, "n", "J", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)

  buf_set_keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  buf_set_keymap(bufnr, "n", "ga", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
end

local util = require("lspconfig").util

-- Inject lsp thingy into nvim-cmp
local capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities())

local flags = {
  debounce_text_changes = 200,
}

-- npm install -g typescript typescript-language-server
require("typescript").setup({
  debug = false,
  server = {
    on_attach = function(_, bufnr)
      on_attach(nil, bufnr)

      -- Mappings.
      local opts = { noremap = true, silent = true }
      buf_set_keymap(bufnr, "n", "gi", "<cmd>TypescriptAddMissingImports<CR>", opts)
      buf_set_keymap(bufnr, "n", "gR", "<cmd>TypescriptRenameFile<CR>", opts)
    end,
    capabilities = capabilities,
    flags = flags,
  },
})

-- npm install -g @astrojs/language-server
require("lspconfig").astro.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
})

-- npm i -g vscode-langservers-extracted
require("lspconfig").jsonls.setup({
  capabilities = capabilities,
})

-- NOTE: I don't use this anymore, but I'm keeping it here for reference; It
-- blocks my development/thinking process.
--
-- npm i -g vscode-langservers-extracted
-- require("lspconfig").eslint.setup({
--   -- Magically fixes eslint on monorepos?
--   -- https://github.com/neovim/nvim-lspconfig/issues/1427#issuecomment-980783000
--   capabilities = capabilities,
--   flags = flags,
--   settings = {
--     workingDirectory = { mode = "location" },
--     codeAction = {
--       disableRuleComment = {
--         enable = true,
--         location = "sameLine",
--       },
--       showDocumentation = {
--         enable = true,
--       },
--     },
--   },
--   root_dir = util.root_pattern(
--     ".eslintrc.js",
--     ".eslintrc.json",
--     ".eslintrc.yaml",
--     ".eslintrc.yml",
--     ".eslintrc",
--     "package.json"
--   ),
-- })

-- npm i -g vscode-langservers-extracted
require("lspconfig").cssls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
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
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
})

-- npm i -g yaml-language-server
require("lspconfig").yamlls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
  settings = {
    schemas = {
      ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
    },
  },
})

-- npm i -g bash-language-server
require("lspconfig").bashls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
})

--  npm install -g @tailwindcss/language-server
require("lspconfig").tailwindcss.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
  settings = {
    tailwindCSS = {
      classAttributes = { "class", "className", "classList" },
      experimental = {
        classRegex = { "tw`(.+?)`" },
      },
    },
  },
})

-- pip install 'python-lsp-server[all]'
require("lspconfig").pylsp.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
})

require("lspconfig").dartls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
})

-- require("lspconfig").sqls.setup({
--   on_attach = lsp_keymaps,
--   capabilities = capabilities,
--   flags = flags,
--   filetype = { "sql", "mysql" },
--   settings = {
--     sqls = {
--       connections = {
--         {
--           driver = "postgresql",
--           dataSourceName = "host=127.0.0.1 port=5432 user=postgres password=postgres dbname=postgres sslmode=disable",
--         },
--       },
--     },
--   },
-- })

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
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
})

-- npm i -g stylelint-lsp
-- require("lspconfig").stylelint_lsp.setup({
--   on_attach = on_attach,
--   capabilities = capabilities,
--   flags = flags,
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
  on_attach = on_attach,
  capabilities = capabilities,
  flags = flags,
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
        library = {
          [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
        },
        maxPreload = 100000,
        preloadFileSize = 10000,
      },
    },
  },
})
