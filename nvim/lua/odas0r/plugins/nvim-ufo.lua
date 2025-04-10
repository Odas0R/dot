return {
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async",
  },
  config = function()
    local ufo = require("ufo")
    local lsp = require("lspconfig")

    ufo.setup({
      provider_selector = function(bufnr, filetype, buftype)
        return { "treesitter", "indent" }
      end,
    })

    lsp.util.default_config = vim.tbl_extend("force", lsp.util.default_config, {
      on_attach = function(client, bufnr)
        ufo.attach(client, bufnr)
      end,
    })

    -- Using ufo provider need remap `zR` and `zM`
    vim.keymap.set("n", "zR", require("ufo").openAllFolds)
    vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
  end,
}
