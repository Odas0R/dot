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
  s("#!", {
    t("#!/bin/bash"),
    i(0),
  }),
  s("safe", {
    t("set -euo pipefail"),
    i(0),
  }),
  s(
    "cmd",
    fmt(
      [[if ! command -v {1}; then
  {2}
fi]],
      {
        i(1, "nvim"),
        i(2, 'echo "Command not found"'),
      }
    )
  ),
  s(
    "taskfile",
    fmt(
      [[
#!/bin/bash
PATH=./node_modules/.bin:$PATH

function {1} {{
  {2}
}}

function build {{
  {3}
}}

function test {{
  {4}
}}

function default {{
  {1}
}}

function help {{
  echo "$0 <task> <args>"
  echo "Tasks:"
  compgen -A function | cat -n
}}

TIMEFORMAT="Task completed in %3lR"
time "${{@:-default}}"
]],
      {
        i(1, "dev"),
        i(2, 'echo "not implemented"'),
        i(3, 'echo "not implemented"'),
        i(4, 'echo "not implemented"'),
      }
    )
  ),
}
