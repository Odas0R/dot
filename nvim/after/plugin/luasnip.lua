local ls = require("luasnip")

ls.snippets = {
  all = {},

  lua = {
    ls.parser.parse_snippet("lf", "local $1 = function($2)\n $0\nend"),
  },
}
