local map = require("odas0r.lib.keymap")

local M = {}

local function organize_typescript_imports(client, bufnr)
  if not client:supports_method("workspace/executeCommand") then
    return
  end

  client:request("workspace/executeCommand", {
    command = "_typescript.organizeImports",
    arguments = { vim.api.nvim_buf_get_name(bufnr) },
  }, nil, bufnr)
end

local function run_goimports(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" then
    return
  end

  vim.cmd.write()
  vim.system({ "goimports", "-w", file }, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(result.stderr, vim.log.levels.ERROR, { title = "goimports" })
        return
      end

      vim.cmd.checktime()
    end)
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("Odas0rLspAttach", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event)
      local bufnr = event.buf
      local client = vim.lsp.get_client_by_id(event.data.client_id)

      if not client then
        return
      end

      vim.api.nvim_set_option_value(
        "omnifunc",
        "v:lua.vim.lsp.omnifunc",
        { buf = bufnr }
      )

      map(
        "n",
        "gd",
        vim.lsp.buf.definition,
        { buffer = bufnr, desc = "Go to definition" }
      )
      map(
        "n",
        "gD",
        vim.lsp.buf.declaration,
        { buffer = bufnr, desc = "Go to declaration" }
      )
      map(
        "n",
        "gi",
        vim.lsp.buf.implementation,
        { buffer = bufnr, desc = "Go to implementation" }
      )
      map(
        "n",
        "gt",
        vim.lsp.buf.type_definition,
        { buffer = bufnr, desc = "Go to type definition" }
      )
      map(
        "n",
        "gh",
        vim.lsp.buf.hover,
        { buffer = bufnr, desc = "Show hover information" }
      )
      map(
        "n",
        "gk",
        vim.lsp.buf.references,
        { buffer = bufnr, desc = "Show references" }
      )
      map(
        "n",
        "go",
        vim.lsp.buf.document_symbol,
        { buffer = bufnr, desc = "Document symbols" }
      )
      map(
        "n",
        "gr",
        vim.lsp.buf.rename,
        { buffer = bufnr, desc = "Rename symbol" }
      )
      map(
        { "n", "v" },
        "ga",
        vim.lsp.buf.code_action,
        { buffer = bufnr, desc = "Code action" }
      )

      map("n", "K", function()
        vim.diagnostic.jump({ count = -1, float = true })
      end, { buffer = bufnr, desc = "Previous diagnostic" })

      map("n", "J", function()
        vim.diagnostic.jump({ count = 1, float = true })
      end, { buffer = bufnr, desc = "Next diagnostic" })

      if client.name == "ts_ls" then
        map("n", "<leader>co", function()
          organize_typescript_imports(client, bufnr)
        end, { buffer = bufnr, desc = "Organize imports" })
      end

      if client.name == "gopls" or client.name == "templ" then
        map("n", "<leader>co", function()
          run_goimports(bufnr)
        end, { buffer = bufnr, desc = "Organize imports" })
      end
    end,
  })
end

return M
