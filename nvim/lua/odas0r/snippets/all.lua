local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

local function trim_system(cmd)
  return vim.trim(vim.fn.system(cmd))
end

local function iso_date()
  return os.date("%Y-%m-%d")
end

local function iso_datetime()
  return os.date("%Y-%m-%dT%H:%M:%S%z")
end

return {
  s("date", {
    f(function()
      return iso_date()
    end),
  }),

  s("datetime", {
    f(function()
      return iso_datetime()
    end),
  }),

  s("uuid", {
    f(function()
      local uuid = trim_system("uuidgen")
      if uuid == "" then
        return "00000000-0000-0000-0000-000000000000"
      end
      return string.lower(uuid)
    end),
  }),

  s("path", {
    f(function()
      return vim.fn.expand("%:p")
    end),
  }),

  s("relpath", {
    f(function()
      return vim.fn.expand("%")
    end),
  }),

  s("filename", {
    f(function()
      return vim.fn.expand("%:t")
    end),
  }),

  s("todo", fmt("TODO({}): {}", { i(1, "context"), i(0, "message") })),
  s("fixme", fmt("FIXME({}): {}", { i(1, "context"), i(0, "message") })),
  s("note", fmt("NOTE({}): {}", { i(1, "context"), i(0, "message") })),
}
