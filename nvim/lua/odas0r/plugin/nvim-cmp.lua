local Utils = require("odas0r.utils")

local M = {}

M.init = function() end

M.config = function()
  -- setup lspkind
  local lspkind = require("lspkind")

  -- remove all icons from lspkind
  for k, _ in pairs(lspkind.presets["default"]) do
    lspkind.presets["default"][k] = ""
  end

  -- Setup nvim-cmp.
  local cmp = require("cmp")

  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        -- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
        require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
        -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
        -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
        -- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)
      end,
    },
    -- This does no "performance" improvement, cmp is very fast.
    -- performance = {
    --   debounce = 150,
    -- },
    experimental = {
      ghost_text = false, -- this feature conflict with copilot.vim's preview.
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    matching = {
      disallow_partial_matching = true,
    },
    mapping = {
      ["<C-n>"] = cmp.mapping.select_next_item(),
      ["<C-p>"] = cmp.mapping.select_prev_item(),
      ["<C-u>"] = cmp.mapping.scroll_docs(-4),
      ["<C-d>"] = cmp.mapping.scroll_docs(4),
      ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    },
    sources = cmp.config.sources({
      {
        name = "zet",
        priority = 1000,
      },
      { name = "luasnip" }, -- For luasnip users.
      { name = "nvim_lua" },
      { name = "nvim_lsp" },
      { name = "path" },
      {
        name = "buffer",
        option = {
          keyword_pattern = [[\k\+]],
          get_bufnrs = function()
            local buf = vim.api.nvim_get_current_buf()
            local byte_size = vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))
            if byte_size > 1024 * 1024 then -- 1 Megabyte max
              return {}
            end
            return { buf }
          end,
        },
      },
      { name = "ultisnips" },
    }),
    formatting = {
      format = lspkind.cmp_format({
        with_text = true,
        menu = {
          nvim_lua = "[Lua]",
          nvim_lsp = "[Lsp]",
          path = "[Path]",
          zet = "[Zet]",
          buffer = "[Buffer]",
          cody = "[Cody]",
        },
      }),
    },
  })
end

return M
