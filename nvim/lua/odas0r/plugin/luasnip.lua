local Utils = require("odas0r.utils")

local M = {}

M.init = function()
  local ls = require("luasnip")

  Utils.map({ "i", "s" }, "<C-L>", function()
    ls.jump(1)
  end)

  Utils.map({ "i", "s" }, "<C-H>", function()
    ls.jump(-1)
  end)

  Utils.map({ "i", "s" }, "<C-E>", function()
    if ls.expand_or_jumpable() then
      ls.expand_or_jump()
    end
  end)

  -- load vscode snippets for now, since we're new to this.
  require("luasnip.loaders.from_vscode").lazy_load()

  -- load custom snippets
  require("luasnip.loaders.from_lua").load({
    paths = os.getenv("HOME") .. "/.config/nvim/lua/odas0r/snippets",
  })
end

M.config = function()
  local ls = require("luasnip")
  local types = require("luasnip.util.types")
  ls.setup({
    keep_roots = true,
    link_roots = true,
    link_children = true,
    -- Update more often, :h events for more info.
    update_events = "TextChanged,TextChangedI",
    -- Snippets aren't automatically removed if their text is deleted.
    -- `delete_check_events` determines on which events (:h events) a check for
    -- deleted snippets is performed.
    -- This can be especially useful when `history` is enabled.
    delete_check_events = "TextChanged",
    ext_opts = {
      [types.choiceNode] = {
        active = {
          virt_text = { { "choiceNode", "Comment" } },
        },
      },
    },
    -- treesitter-hl has 100, use something higher (default is 200).
    ext_base_prio = 300,
    -- minimal increase in priority.
    ext_prio_increase = 1,
    enable_autosnippets = true,
  })
end

return M
