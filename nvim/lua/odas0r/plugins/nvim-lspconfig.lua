local Utils = require("odas0r.utils")

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local on_attach = function(_, bufnr)
      -- Enable completion triggered by <c-x><c-o>
      Utils.set_option("omnifunc", "v:lua.vim.lsp.omnifunc", { buf = bufnr })

      -- Common mappings for all language servers
      Utils.map(
        "n",
        "gd",
        vim.lsp.buf.definition,
        { buffer = bufnr, desc = "Go to definition" }
      )
      Utils.map(
        "n",
        "gD",
        vim.lsp.buf.declaration,
        { buffer = bufnr, desc = "Go to declaration" }
      )
      Utils.map(
        "n",
        "gi",
        vim.lsp.buf.implementation,
        { buffer = bufnr, desc = "Go to implementation" }
      )
      Utils.map(
        "n",
        "gh",
        vim.lsp.buf.hover,
        { buffer = bufnr, desc = "Show hover information" }
      )
      Utils.map(
        "n",
        "gk",
        vim.lsp.buf.references,
        { buffer = bufnr, desc = "Show references" }
      )
      Utils.map("n", "K", function()
        vim.diagnostic.jump({ count = -1, float = true })
      end, { buffer = bufnr, desc = "Previous diagnostic" })
      Utils.map("n", "J", function()
        vim.diagnostic.jump({ count = 1, float = true })
      end, { buffer = bufnr, desc = "Next diagnostic" })
      Utils.map(
        "n",
        "gr",
        vim.lsp.buf.rename,
        { buffer = bufnr, desc = "Rename symbol" }
      )
      Utils.map(
        "n",
        "ga",
        vim.lsp.buf.code_action,
        { buffer = bufnr, desc = "Code action" }
      )
    end

    local util = vim.lsp.util

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

    vim.lsp.config("*", {
      capabilities = capabilities,
      flags = flags,
      root_markers = { ".git" },
    })

    -- set log level to debug for debugging
    -- vim.lsp.set_log_level("DEBUG")

    -- npm install -g typescript typescript-language-server
    vim.lsp.config("ts_ls", {
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
        Utils.map(
          "n",
          "gD",
          "<cmd>lua vim.lsp.buf.type_definition()<CR>",
          { buf = bufnr }
        )
        Utils.map(
          "n",
          "go",
          "<cmd>lua vim.lsp.buf.document_symbol()<CR>",
          { buf = bufnr }
        )
        Utils.map("n", "go", organize_imports, { buf = bufnr })
      end,
    })
    vim.lsp.enable("ts_ls")

    -- npm install -g @astrojs/language-server
    vim.lsp.config("astro", {
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
        Utils.map(
          "n",
          "gD",
          "<cmd>lua vim.lsp.buf.type_definition()<CR>",
          { buf = bufnr }
        )
        Utils.map(
          "n",
          "gi",
          "<cmd>lua vim.lsp.buf.implementation()<CR>",
          { buf = bufnr }
        )
        Utils.map(
          "n",
          "go",
          "<cmd>lua vim.lsp.buf.document_symbol()<CR>",
          { buf = bufnr }
        )
        Utils.map("n", "gu", organize_imports, { buf = bufnr })
        Utils.map("n", "go", organize_imports, { buf = bufnr })
      end,
    })
    vim.lsp.enable("astro")

    -- Fix for bug https://github.com/neovim/neovim/issues/12970
    vim.lsp.util.apply_text_document_edit = function(
      text_document_edit,
      index,
      offset_encoding
    )
      local text_document = text_document_edit.textDocument
      local buf = vim.uri_to_bufnr(text_document.uri)
      if offset_encoding == nil then
        vim.notify_once(
          "apply_text_document_edit must be called with valid offset encoding",
          vim.log.levels.WARN
        )
      end

      vim.lsp.util.apply_text_edits(
        text_document_edit.edits,
        buf,
        offset_encoding
      )
    end

    -- npm i -g vscode-langservers-extracted
    vim.lsp.enable("jsonls")

    -- npm i -g vscode-langservers-extracted
    vim.lsp.config("cssls", {
      on_attach = on_attach,
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
    vim.lsp.enable("cssls")

    -- npm i -g yaml-language-server
    vim.lsp.config("yamlls", {
      on_attach = on_attach,
      settings = {
        schemas = {
          ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
        },
      },
    })
    vim.lsp.enable("yamlls")

    -- npm i -g bash-language-server
    vim.lsp.config("bashls", {
      on_attach = on_attach,
    })
    vim.lsp.enable("bashls")

    --  npm install -g @tailwindcss/language-server
    vim.lsp.config("tailwindcss", {
      on_attach = on_attach,
      filetypes = {
        "templ",
        "astro",
        "html",
        "css",
        "javascript",
        "typescript",
      },
      init_options = { userLanguages = { templ = "html" } },
    })
    vim.lsp.enable("tailwindcss")

    -- pip install 'python-lsp-server[all]'
    -- pip install pylsp-rope
    -- pip install autoimport
    vim.lsp.config("pylsp", {
      on_attach = on_attach,
    })
    vim.lsp.enable("pylsp")

    vim.lsp.config("dartls", {
      on_attach = on_attach,
    })
    vim.lsp.enable("dartls")

    vim.lsp.config("marksman", {
      on_attach = on_attach,
    })
    vim.lsp.enable("marksman")

    -- sudo apt-get install clangd-14
    -- sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-14 100
    vim.lsp.config("clangd", {
      on_attach = on_attach,
    })
    vim.lsp.enable("clangd")

    -- go install golang.org/x/tools/gopls@latest
    -- go install golang.org/x/tools/cmd/goimports@latest
    vim.lsp.config("gopls", {
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
    })
    vim.lsp.enable("gopls")

    vim.lsp.config("html", {
      on_attach = on_attach,
      filetypes = { "html", "templ" },
    })
    vim.lsp.enable("html")

    vim.lsp.config("templ", {
      capabilities = capabilities,
      on_attach = function(_, bufnr)
        on_attach(_, bufnr)
        Utils.map("n", "gi", ":silent! !goimports -w %<CR>", { buf = bufnr })
      end,
    })
    vim.lsp.enable("templ")

    vim.lsp.config("efm", {
      on_attach = on_attach,
      init_options = { documentFormatting = false },
      filetypes = { "sh" },
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
    vim.lsp.enable("efm")

    -- LSP for lua
    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#sumneko_lua
    local sumneko_binary_path = vim.fn.exepath("lua-language-server")
    local sumneko_root_path = vim.fn.fnamemodify(sumneko_binary_path, ":h:h:h")

    local runtime_path = vim.split(package.path, ";")
    table.insert(runtime_path, "lua/?.lua")
    table.insert(runtime_path, "lua/?/init.lua")

    vim.lsp.config("lua_ls", {
      on_attach = on_attach,
      cmd = {
        sumneko_binary_path,
        "-E",
        sumneko_root_path .. "/lua-language-server/main.lua",
      },
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
    vim.lsp.enable("lua_ls")
  end,
}
