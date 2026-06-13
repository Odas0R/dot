local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

local function bfmt(body, nodes)
  return fmt(body, nodes, { delimiters = "[]" })
end

return {
  s(
    "---",
    bfmt(
      [[
---
[body]
---]],
      { body = i(0, "// frontmatter") }
    )
  ),

  s(
    "map",
    bfmt(
      [[
{[items].map(([item]) => (
  <[tag]>
    [body]
  </[tag_close]>
))}]],
      { items = i(1, "items"), item = i(2, "item"), tag = i(3, "div"), body = i(0, "{item}"), tag_close = i(4, "div") }
    )
  ),

  s(
    "script",
    bfmt(
      [[
<script>
  [body]
</script>]],
      { body = i(0) }
    )
  ),

  s(
    "style",
    bfmt(
      [[
<style>
  [selector] {
    [body]
  }
</style>]],
      { selector = i(1, ".class"), body = i(0) }
    )
  ),

}
