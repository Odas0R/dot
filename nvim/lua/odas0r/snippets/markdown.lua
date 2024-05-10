local ls = require("luasnip")
-- shorthands
local s = ls.snippet
-- local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
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
--
local function list_number(args, parent, user_args)
  local index = tonumber(parent.snippet.env.LS_SELECT_RAW or parent.snippet.env.LS_CURSOR_POS[2])
  return tostring(index) .. ". "
end

return {
 -- Bold italic text snippet when typing **
  s({ trig = "**", wordTrig = false, priority = 100 }, fmt("***{}***{}", { i(1, "text"), i(0) })),
  -- Bold text snippet when typing *
  s({ trig = "*", wordTrig = false, priority = 50 }, fmt("**{}**{}", { i(1, "text"), i(0) })),
  -- Italic text snippet when typing _
  s("_", fmt("_{}_ {}", { i(1, "text"), i(0) })),
  -- Code block snippet
  s("code", fmt("```{}\n{}\n```", { i(1, "language"), i(2, "code") })),
  -- Link snippet
  s("link", fmt("[{}]({})", { i(1, "text"), i(2, "url") })),
  -- Image snippet
  s("img", fmt("![{}]({})", { i(1, "alt text"), i(2, "url") })),

  -- Tables
  s("2x1", fmt([[
| {} | {} |
|---|---|
| {} | {} |
]],
    {
      i(1, "header1"),
      i(2, "header2"),
      i(3, "row1_col1"),
      i(4, "row1_col2"),
    }
  )),

  -- 2x2 table
  s("2x2", fmt([[
| {} | {} |
|---|---|
| {} | {} |
| {} | {} |
]],
    {
      i(1, "header1"),
      i(2, "header2"),
      i(3, "row1_col1"),
      i(4, "row1_col2"),
      i(5, "row2_col1"),
      i(6, "row2_col2"),
    }
  )),

  -- 2x3 table
  s("2x3", fmt([[
| {} | {} |
|---|---|
| {} | {} |
| {} | {} |
| {} | {} |
]],
    {
      i(1, "header1"),
      i(2, "header2"),
      i(3, "row1_col1"),
      i(4, "row1_col2"),
      i(5, "row2_col1"),
      i(6, "row2_col2"),
      i(7, "row3_col1"),
      i(8, "row3_col2"),
    }
  )),

  -- 3x3 table
  s("3x3", fmt([[
| {} | {} | {} |
|---|---|---|
| {} | {} | {} |
| {} | {} | {} |
| {} | {} | {} |
]],
    {
      i(1, "header1"),
      i(2, "header2"),
      i(3, "header3"),
      i(4, "row1_col1"),
      i(5, "row1_col2"),
      i(6, "row1_col3"),
      i(7, "row2_col1"),
      i(8, "row2_col2"),
      i(9, "row2_col3"),
      i(10, "row3_col1"),
      i(11, "row3_col2"),
      i(12, "row3_col3"),
    }
  )),

  -- 3x4 table
  s("4x3", fmt([[
| {} | {} | {} | {} |
|---|---|---|---|
| {} | {} | {} | {} |
| {} | {} | {} | {} |
| {} | {} | {} | {} |
]],
    {
      i(1, "header1"),
      i(2, "header2"),
      i(3, "header3"),
      i(4, "header4"),
      i(5, "row1_col1"),
      i(6, "row1_col2"),
      i(7, "row1_col3"),
      i(8, "row1_col4"),
      i(9, "row2_col1"),
      i(10, "row2_col2"),
      i(11, "row2_col3"),
      i(12, "row2_col4"),
      i(13, "row3_col1"),
      i(14, "row3_col2"),
      i(15, "row3_col3"),
      i(16, "row3_col4"),
    }
  )),

  -- 4x4 table
  s("4x4", fmt([[
| {} | {} | {} | {} |
|---|---|---|---|
| {} | {} | {} | {} |
| {} | {} | {} | {} |
| {} | {} | {} | {} |
| {} | {} | {} | {} |
]],
    {
      i(1, "header1"),
      i(2, "header2"),
      i(3, "header3"),
      i(4, "header4"),
      i(5, "row1_col1"),
      i(6, "row1_col2"),
      i(7, "row1_col3"),
      i(8, "row1_col4"),
      i(9, "row2_col1"),
      i(10, "row2_col2"),
      i(11, "row2_col3"),
      i(12, "row2_col4"),
      i(13, "row3_col1"),
      i(14, "row3_col2"),
      i(15, "row3_col3"),
      i(16, "row3_col4"),
      i(17, "row4_col1"),
      i(18, "row4_col2"),
      i(19, "row4_col3"),
      i(20, "row4_col4"),
    }
  )),
}
