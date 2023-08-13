local Utils = require("odas0r.utils")

local M = {}

M.init = function()
  vim.g.UltiSnipsEditSplit = "vertical"
  vim.g.UltiSnipsSnippetDirectories = { "~/snippets/ultisnips" }
  Utils.autocmd("BufWritePost", {
    group = Utils.augroup("ReloadSnippets"),
    pattern = "*.snippets",
    callback = function()
      vim.cmd("CmpUltisnipsReloadSnippets")
    end,
  })
end

M.config = function()
  -- setup lspkind
  local lspkind = require("lspkind")

  -- remove all icons from lspkind
  for k, _ in pairs(lspkind.presets["default"]) do
    lspkind.presets["default"][k] = ""
  end

  -- Setup nvim-cmp.
  local cmp = require("cmp")
  local cmp_ultisnips_mappings = require("cmp_nvim_ultisnips.mappings")

  cmp.setup({
    snippet = {
      expand = function(args)
        vim.fn["UltiSnips#Anon"](args.body)
      end,
    },
    -- This does no "performance" improvement, cmp is very fast.
    performance = {
      trigger_debounce_time = 100,
    },
    experimental = {
      ghost_text = false, -- this feature conflict with copilot.vim's preview.
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    mapping = {
      ["<C-n>"] = cmp.mapping.select_next_item(),
      ["<C-p>"] = cmp.mapping.select_prev_item(),
      ["<C-u>"] = cmp.mapping.scroll_docs(-4),
      ["<C-d>"] = cmp.mapping.scroll_docs(4),
      ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
      ["<C-j>"] = cmp.mapping(function(fallback)
        cmp_ultisnips_mappings.expand_or_jump_forwards(fallback)
      end, {
        "i",
        "s", --[[ "c" (to enable the mapping in command mode) ]]
      }),
      ["<C-k>"] = cmp.mapping(function(fallback)
        cmp_ultisnips_mappings.jump_backwards(fallback)
      end, {
        "i",
        "s", --[[ "c" (to enable the mapping in command mode) ]]
      }),
    },
    sources = cmp.config.sources({
      { name = "nvim_lua" },
      { name = "nvim_lsp" },
      { name = "path" },
      { name = "zet" }, -- /lua/
      {
        name = "buffer",
        option = {
          keyword_pattern = [[\k\+]],
        },
      },
      { name = "vim-dadbod-completion" },
      { name = "ultisnips" },
    }),
    formatting = {
      format = lspkind.cmp_format({
        with_text = true,
        menu = {
          nvim_lua = "[Lua]",
          nvim_lsp = "[Lsp]",
          path = "[Path]",
          ["vim-dadbod-completion"] = "[SQL]",
          ultisnips = "[Snip]",
          buffer = "[Buffer]",
        },
      }),
    },
  })
end

return M