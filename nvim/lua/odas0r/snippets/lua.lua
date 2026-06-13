local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local rep = require("luasnip.extras").rep
local fmt = require("luasnip.extras.fmt").fmt

local function afmt(body, nodes)
  return fmt(body, nodes, { delimiters = "<>" })
end

return {
  s("req", fmt('local {} = require("{}")', { i(1, "mod"), i(2, "module") })),

  s(
    "preq",
    afmt(
      [[
local ok, <mod> = pcall(require, "<module>")
if not ok then
  return
end]],
      { mod = i(1, "mod"), module = i(2, "module") }
    )
  ),

  s(
    "lf",
    afmt(
      [[
local function <name>(<args>)
  <body>
end]],
      { name = i(1, "name"), args = i(2), body = i(0) }
    )
  ),

  s(
    "fn",
    afmt(
      [[
function <name>(<args>)
  <body>
end]],
      { name = i(1, "name"), args = i(2), body = i(0) }
    )
  ),

  s(
    "mod",
    afmt(
      [[
local M = {}

function M.<name>(<args>)
  <body>
end

return M]],
      { name = i(1, "setup"), args = i(2), body = i(0) }
    )
  ),

  s(
    "setup",
    afmt(
      [[
local M = {}

local defaults = {
  <defaults>
}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  <body>
end

return M]],
      { defaults = i(1), body = i(0) }
    )
  ),

  s(
    "plug",
    afmt(
      [[
return {
  "<repo>",
  event = "<event>",
  opts = {
    <opts>
  },
}]],
      { repo = i(1, "author/plugin.nvim"), event = i(2, "VeryLazy"), opts = i(0) }
    )
  ),

  s(
    "map",
    afmt(
      [[
vim.keymap.set("<mode>", "<lhs>", <rhs>, { desc = "<desc>" })]],
      { mode = i(1, "n"), lhs = i(2, "<leader>"), rhs = i(3, "function() end"), desc = i(4, "Description") }
    )
  ),

  s(
    "cmd",
    afmt(
      [[
vim.api.nvim_create_user_command("<name>", function(opts)
  <body>
end, {
  nargs = "<nargs>",
  desc = "<desc>",
})]],
      { name = i(1, "CommandName"), body = i(0), nargs = i(2, "*"), desc = i(3, "Description") }
    )
  ),

  s(
    "au",
    afmt(
      [[
vim.api.nvim_create_autocmd("<event>", {
  group = vim.api.nvim_create_augroup("<group>", { clear = true }),
  pattern = "<pattern>",
  desc = "<desc>",
  callback = function(event)
    <body>
  end,
})]],
      { event = i(1, "BufWritePre"), group = i(2, "group_name"), pattern = i(3, "*"), desc = i(4, "Description"), body = i(0) }
    )
  ),

  s("notify", fmt('vim.notify("{}", vim.log.levels.{})', { i(1, "message"), i(2, "INFO") })),
  s("inspect", fmt("vim.print({})", { i(1, "value") })),

  s(
    "describe",
    afmt(
      [[
describe("<subject>", function()
  it("<behavior>", function()
    <body>
  end)
end)]],
      { subject = i(1, "subject"), behavior = i(2, "does something"), body = i(0) }
    )
  ),

  s(
    "it",
    afmt(
      [[
it("<behavior>", function()
  <body>
end)]],
      { behavior = i(1, "does something"), body = i(0) }
    )
  ),

  s(
    "forp",
    afmt(
      [[
for <key>, <value> in pairs(<table>) do
  <body>
end]],
      { key = i(1, "key"), value = i(2, "value"), table = i(3, "table"), body = i(0) }
    )
  ),

  s(
    "fori",
    afmt(
      [[
for <index>, <value> in ipairs(<items>) do
  <body>
end]],
      { index = i(1, "index"), value = i(2, "value"), items = i(3, "items"), body = i(0) }
    )
  ),

  s(
    "pcall",
    afmt(
      [[
local ok, result = pcall(<fn>, <args>)
if not ok then
  <body>
end]],
      { fn = i(1, "fn"), args = i(2), body = i(0, "return") }
    )
  ),

  s(
    "lazyopts",
    afmt(
      [[
opts = function(_, opts)
  <body>
  return opts
end,]],
      { body = i(0) }
    )
  ),

  s("same", fmt("{} = {}", { i(1, "name"), rep(1) })),
}
