local M = {}

-- TODO: is not perfect can be perfected but does its job :)
M.get_unique_words = function(qflist)
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

M.replace = function(args)
  local pattern, replacement = args:match("^['\"](.-)['\"]%s+['\"](.-)['\"]$")
  if not pattern or not replacement then
    pattern, replacement = args:match("^(%S+)%s+(%S+)$")
  end

  if not pattern or not replacement then
    vim.cmd("echo 'Invalid input format.'")
    return
  end

  pattern = pattern:gsub("/", "\\/")
  replacement = replacement:gsub("/", "\\/")

  local qflist = vim.fn.getqflist()
  for _, item in ipairs(qflist) do
    local bufnr = item.bufnr
    local lnum = item.lnum
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    local modified_line = line:gsub(pattern, replacement)
    vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { modified_line })
  end
end

M.autocomplete = function(arg_lead, cmd_line, cursor_pos)
  local words = M.get_unique_words(vim.fn.getqflist())
  local matches = {}

  -- print(vim.inspect(words))

  for _, word in ipairs(words) do
    if word:find("^" .. arg_lead) then
      table.insert(matches, word)
    end
  end

  return matches
end

return M
