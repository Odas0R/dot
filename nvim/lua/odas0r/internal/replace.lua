local M = {}

-- TODO: is not perfect can be perfected but does its job :)
local get_unique_words = function(qflist)
  local words = {}
  local unique_words = {}
  for _, item in ipairs(qflist) do
    local line = item.text
    if line ~= nil then
      for word in line:gmatch("%S+") do
        if not words[word] then
          words[word] = true
          table.insert(unique_words, word)
        end
      end
    end
  end
  return unique_words
end

local autocomplete = function(arg_lead, cmd_line, cursor_pos)
  local words = get_unique_words(vim.fn.getqflist())
  local matches = {}

  -- print(vim.inspect(words))

  for _, word in ipairs(words) do
    if word:find("^" .. arg_lead) then
      table.insert(matches, word)
    end
  end

  return matches
end

local utils = require("odas0r.utils")

-- FIX: fix this is not totally working
-- M.replace(opts.fargs[1])
utils.cmd("Replace", function(opts)
  local args = opts.fargs[1]

  local pattern, replacement = args:match("^['\"](.-)['\"]%s+['\"](.-)['\"]$")
  if not pattern or not replacement then
    pattern, replacement = args:match("^(%S+)%s+(%S+)$")
  end

  if not pattern or not replacement then
    vim.cmd("echo 'Invalid input format.'")
    return
  end
  -- replace using vim command
  vim.cmd("silent cdo s/" .. pattern .. "/" .. replacement .. "/g | update")
end, {
  nargs = 1,
  desc = "Replace a pattern with another pattern",
  complete = function(arg_lead, cmd_line, cursor_pos)
    return autocomplete(arg_lead, cmd_line, cursor_pos)
  end,
})

return M
