local Utils = require("odas0r.utils")
local M = {}

M.init = function()
  local ls = require("luasnip")
  Utils.map({ "i", "s" }, "<C-w>", function()
    ls.jump(-1)
  end)
  Utils.map({ "i", "s" }, "<C-e>", function()
    if ls.expand_or_jumpable() then
      ls.expand_or_jump()
    end
  end)

  -- Add command to edit snippets
  Utils.cmd("LuaSnipEdit", function()
    local ft = vim.bo.filetype
    local filepath = string.format("%s/.config/nvim/lua/odas0r/snippets/%s.lua", os.getenv("HOME"), ft)

    -- Create the file if it doesn't exist
    local file = io.open(filepath, "r")
    if not file then
      file = io.open(filepath, "w")
      if file then
        file:write([[
local ls = require("luasnip")
-- shorthands
local s = ls.snippet
-- local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
-- local f = ls.function_node
-- local c = ls.choice_node
-- local d = ls.dynamic_node
-- local r = ls.restore_node
-- local l = require("luasnip.extras").lambda
-- local rep = require("luasnip.extras").rep
-- local p = require("luasnip.extras").partial
-- local m = require("luasnip.extras").match
-- local n = require("luasnip.extras").nonempty
-- local dl = require("luasnip.extras").dynamic_lambda
local fmt = require("luasnip.extras.fmt").fmt
-- local fmta = require("luasnip.extras.fmt").fmta
-- local types = require("luasnip.util.types")
-- local conds = require("luasnip.extras.conditions")
-- local conds_expand = require("luasnip.extras.conditions.expand")

return {
  -- Add your snippets here
  -- Example:
  -- s("trigger", {
  --   t("expansion"),
  --   i(0),
  -- }),
}
]])
        file:close()
      end
    end

    -- Open the snippet file
    vim.cmd("edit " .. filepath)
  end, {})

  -- load vscode snippets for now, since we're new to this.
  require("luasnip.loaders.from_vscode").lazy_load()
  -- load custom snippets
  require("luasnip.loaders.from_lua").load({
    paths = os.getenv("HOME") .. "/.config/nvim/lua/odas0r/snippets",
  })

  -- Add auto-reload on save
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = os.getenv("HOME") .. "/.config/nvim/lua/odas0r/snippets/*.lua",
    callback = function()
      require("luasnip.loaders.from_lua").load({
        paths = os.getenv("HOME") .. "/.config/nvim/lua/odas0r/snippets",
      })
    end,
  })
end

M.config = function()
  -- Rest of your config remains the same
  local ls = require("luasnip")
  local types = require("luasnip.util.types")
  ls.setup({
    keep_roots = true,
    link_roots = true,
    link_children = true,
    update_events = "TextChanged,TextChangedI",
    delete_check_events = "TextChanged",
    ext_opts = {
      [types.choiceNode] = {
        active = {
          virt_text = { { "choiceNode", "Comment" } },
        },
      },
    },
    ext_base_prio = 300,
    ext_prio_increase = 1,
    enable_autosnippets = true,
  })
end

return M
