local Utils = require("odas0r.utils")

local M = {}

M.init = function() end

M.config = function()
  local on_attach = function(_, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    Utils.set_option("omnifunc", "v:lua.vim.lsp.omnifunc", { buf = bufnr })

    -- Common mappings for all language servers
    Utils.map("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Go to definition" })
    Utils.map("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Go to declaration" })
    Utils.map("n", "gi", vim.lsp.buf.implementation, { buffer = bufnr, desc = "Go to implementation" })
    Utils.map("n", "gh", vim.lsp.buf.hover, { buffer = bufnr, desc = "Show hover information" })
    Utils.map("n", "gk", vim.lsp.buf.references, { buffer = bufnr, desc = "Show references" })
    Utils.map("n", "K", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, { buffer = bufnr, desc = "Previous diagnostic" })
    Utils.map("n", "J", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, { buffer = bufnr, desc = "Next diagnostic" })
    Utils.map("n", "gr", vim.lsp.buf.rename, { buffer = bufnr, desc = "Rename symbol" })
    Utils.map("n", "ga", vim.lsp.buf.code_action, { buffer = bufnr, desc = "Code action" })
  end

  local util = require("lspconfig").util

  local flags = {
    debounce_text_changes = 50,
  }

  local function default_capabilities()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem = {
      documentationFormat = { "markdown", "plaintext" },
      snippetSupport = true,
      preselectSupport = true,
      insertReplaceSupport = true,
      labelDetailsSupport = true,
      deprecatedSupport = true,
      commitCharactersSupport = true,
      tagSupport = { valueSet = { 1 } },
      resolveSupport = {
        properties = {
          "documentation",
          "detail",
          "additionalTextEdits",
        },
      },
    }
    -- AstroLSP needs this
    capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true
    return capabilities
  end

  -- Inject nvim_cmp capabilities into LSP capabilities
  local capabilities = vim.tbl_deep_extend(
    "keep",
    default_capabilities(),
    require("cmp_nvim_lsp").default_capabilities()
  )

  -- set log level to debug for debugging
  -- vim.lsp.set_log_level("DEBUG")

  -- npm install -g typescript typescript-language-server
  require("lspconfig").ts_ls.setup({
    on_attach = function(client, bufnr)
      on_attach(client, bufnr)

      local function organize_imports()
        if client.supports_method("workspace/executeCommand") then
          client:request("workspace/executeCommand", {
            command = "_typescript.organizeImports",
            arguments = { vim.api.nvim_buf_get_name(0) },
          })
        end
      end

      -- Mappings.
      Utils.map("n", "gD", "<cmd>lua vim.lsp.buf.type_definition()<CR>", { buf = bufnr })
      Utils.map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", { buf = bufnr })
      Utils.map("n", "go", "<cmd>lua vim.lsp.buf.document_symbol()<CR>", { buf = bufnr })
      Utils.map("n", "gu", organize_imports, { buf = bufnr })
      Utils.map("n", "go", organize_imports, { buf = bufnr })
    end,
    capabilities = capabilities,
    flags = flags,
  })

  -- require("lspconfig").denols.setup({
  --   on_attach = on_attach,
  --   capabilities = capabilities,
  --   -- root_dir = util.root_pattern("package.json"),
  -- })

  -- npm install -g @astrojs/language-server
  require("lspconfig").astro.setup({
    on_attach = function(client, bufnr)
      on_attach(client, bufnr)

      local function organize_imports()
        if client.supports_method("workspace/executeCommand") then
          client:request("workspace/executeCommand", {
            command = "_typescript.organizeImports",
            arguments = { vim.api.nvim_buf_get_name(0) },
          })
        end
      end

      -- Mappings.
      Utils.map("n", "gD", "<cmd>lua vim.lsp.buf.type_definition()<CR>", { buf = bufnr })
      Utils.map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", { buf = bufnr })
      Utils.map("n", "go", "<cmd>lua vim.lsp.buf.document_symbol()<CR>", { buf = bufnr })
      Utils.map("n", "gu", organize_imports, { buf = bufnr })
      Utils.map("n", "go", organize_imports, { buf = bufnr })
    end,
    capabilities = capabilities,
    flags = flags,
    init_options = {
      typescript = {
        tsdk = (function()
          local current_dir = vim.fn.getcwd()

          -- Start from current directory and traverse up until we find node_modules/typescript
          local dir = current_dir
          while dir ~= "/" do
            local ts_path = dir .. "/node_modules/typescript/lib"
            if vim.fn.isdirectory(ts_path) == 1 then
              return ts_path
            end
            dir = vim.fn.fnamemodify(dir, ":h")
          end

          return nil
        end)(),
      },
    },
    -- Adjust root_dir to handle monorepo structure
    root_dir = function(fname)
      -- Check for both the workspace root and the individual package root
      local util = require("lspconfig").util
      return util.root_pattern("tsconfig.json", "package.json")(fname) or util.find_git_ancestor(fname)
    end,
  })

  -- npm i -g vscode-langservers-extracted
  require("lspconfig").jsonls.setup({
    capabilities = capabilities,
  })

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
  --     ".eslintrc.cjs",
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
    filetypes = { "templ", "astro", "html", "css", "javascript", "typescript" },
    init_options = { userLanguages = { templ = "html" } },
  })

  -- pip install 'python-lsp-server[all]'
  -- require("lspconfig").pylsp.setup({
  --   on_attach = on_attach,
  --   capabilities = capabilities,
  --   flags = flags,
  -- })

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

  require("lspconfig").marksman.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    flags = flags,
  })

  -- sudo apt-get install clangd-14
  -- sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-14 100
  require("lspconfig").clangd.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    flags = flags,
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
    on_attach = function(_, bufnr)
      on_attach(_, bufnr)
      Utils.map("n", "gi", ":silent! !goimports -w %<CR>", { buf = bufnr })
    end,
    capabilities = capabilities,
    flags = flags,
  })

  require("lspconfig").html.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    filetypes = { "html", "templ" },
  })

  require("lspconfig").templ.setup({
    capabilities = capabilities,
    on_attach = function(_, bufnr)
      on_attach(_, bufnr)
      Utils.map("n", "gi", ":silent! !goimports -w %<CR>", { buf = bufnr })
    end,
    flags = flags,
  })

  require("lspconfig").efm.setup({
    on_attach = on_attach,
    init_options = { documentFormatting = false },
    filetypes = { "sh" },
    root_dir = function(fname)
      return util.root_pattern(".git")(fname) or ""
    end,
    settings = {
      rootMarkers = { ".git/" },
      languages = {
        sh = {
          lintCommand = "shellcheck --format=gcc -x",
          lintSource = "Shellcheck",
          lintFormats = {
            "%f:%l:%c: %trror: %m",
            "%f:%l:%c: %tarning: %m",
            "%f:%l:%c: %tote: %m",
          },
        },
      },
    },
  })

  -- npm i -g stylelint-lsp
  -- require("lspconfig").stylelint_lsp.setup({
  --   on_attach = on_attach,
  --   capabilities = capabilities,
  --   flags = flags,
  --   filetypes = { "css", "less", "scss" },
  -- })
  --

  -- ========== Make sure you have: =============
  --
  -- sudo apt install lua5.1
  -- sudo apt install luajit
  -- sudo apt install luarocks
  -- luarocks install busted

  -- LSP for lua
  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#sumneko_lua
  local sumneko_binary_path = vim.fn.exepath("lua-language-server")
  local sumneko_root_path = vim.fn.fnamemodify(sumneko_binary_path, ":h:h:h")

  local runtime_path = vim.split(package.path, ";")
  table.insert(runtime_path, "lua/?.lua")
  table.insert(runtime_path, "lua/?/init.lua")

  require("lspconfig").lua_ls.setup({
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
          globals = {
            "vim",
          },
        },
        -- Do not send telemetry data containing a randomized but unique identifier
        telemetry = {
          enable = false,
        },
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = {
            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
            [vim.fn.expand("$HOME/.config/nvim/lua/busted-stubs")] = true,
          },
          maxPreload = 100000,
          preloadFileSize = 10000,
        },
      },
    },
  })
end

return M
