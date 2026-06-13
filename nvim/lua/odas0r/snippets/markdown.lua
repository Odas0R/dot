local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

local function today()
  return os.date("%Y-%m-%d")
end

return {
  s({ trig = "**", wordTrig = false, priority = 100 }, fmt("***{}***{}", { i(1, "text"), i(0) })),
  s({ trig = "*", wordTrig = false, priority = 50 }, fmt("**{}**{}", { i(1, "text"), i(0) })),
  s({ trig = "_", wordTrig = false }, fmt("_{}_{}", { i(1, "text"), i(0) })),

  s("@today", {
    f(function()
      return today()
    end),
  }),

  s("@h1", fmt("# {}", { i(1, "Heading") })),
  s("@h2", fmt("## {}", { i(1, "Heading") })),
  s("@h3", fmt("### {}", { i(1, "Heading") })),
  s("@link", fmt("[{}]({}){}", { i(1, "text"), i(2, "url"), i(0) })),
  s("@img", fmt("![{}]({}){}", { i(1, "alt text"), i(2, "url"), i(0) })),
  s("@ref", fmt("[{}][{}]\n\n[{}]: {}", { i(1, "text"), i(2, "id"), i(3, "id"), i(0, "url") })),

  s("@code", fmt("```{}\n{}\n```{}", { i(1, "language"), i(2, "code"), i(0) })),
  s("@quote", fmt("> {}", { i(1, "quote") })),
  s("@task", fmt("- [ ] {}", { i(1, "task") })),
  s("@done", fmt("- [x] {}", { i(1, "task") })),

  s(
    "@front",
    fmt(
      [[
---
title: "{}"
date: {}
tags:
  - {}
---

{}]],
      {
        i(1, "Title"),
        f(function()
          return today()
        end),
        i(2, "tag"),
        i(0),
      }
    )
  ),

  s(
    "@daily",
    fmt(
      [[
# {}

## Priorities

- [ ] {}

## Notes

- {}

## Log

- {}]],
      {
        f(function()
          return today()
        end),
        i(1, "priority"),
        i(2, "note"),
        i(0),
      }
    )
  ),

  s(
    "@callout",
    fmt(
      [[
> [!{}] {}
> {}]],
      { i(1, "NOTE"), i(2, "Title"), i(0, "Body") }
    )
  ),

  s(
    "@details",
    fmt(
      [[
<details>
<summary>{}</summary>

{}

</details>]],
      { i(1, "Summary"), i(0, "Details") }
    )
  ),

  s(
    "@2x2",
    fmt(
      [[
| {} | {} |
|---|---|
| {} | {} |
| {} | {} |]],
      {
        i(1, "header1"),
        i(2, "header2"),
        i(3, "row1_col1"),
        i(4, "row1_col2"),
        i(5, "row2_col1"),
        i(6, "row2_col2"),
      }
    )
  ),

  s(
    "@3x3",
    fmt(
      [[
| {} | {} | {} |
|---|---|---|
| {} | {} | {} |
| {} | {} | {} |
| {} | {} | {} |]],
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
    )
  ),
}
