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

local function replace_in_file(file_path, pattern, replacement, qflist)
  -- Read the entire file content
  local content = {}
  for line in io.lines(file_path) do
    content[#content + 1] = line
  end

  -- Perform replacements in memory
  for _, item in ipairs(qflist) do
    if vim.fn.bufname(item.bufnr) == file_path then
      local lnum = item.lnum
      local modified_line = content[lnum]:gsub(pattern, replacement)
      content[lnum] = modified_line
    end
  end

  -- Write the modified content back to the file
  local file = io.open(file_path, "w")
  if file then
    for _, line in ipairs(content) do
      file:write(line .. "\n")
    end
    file:close()
  else
    vim.cmd("echo 'Could not open file: " .. file_path .. "'")
  end
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

  local qflist = vim.fn.getqflist()

  -- Group qflist items by file path
  local files = {}
  for _, item in ipairs(qflist) do
    local file_path = vim.fn.bufname(item.bufnr)
    if not files[file_path] then
      files[file_path] = {}
    end
    table.insert(files[file_path], item)
  end

  -- Create coroutines for each file replacement
  local coroutines = {}
  for file_path, items in pairs(files) do
    local co = coroutine.create(function()
      replace_in_file(file_path, pattern, replacement, items)
    end)
    table.insert(coroutines, co)
  end

  -- Run coroutines concurrently
  local running = true
  while running do
    running = false
    for _, co in ipairs(coroutines) do
      if coroutine.status(co) ~= "dead" then
        running = true
        local _, err = coroutine.resume(co)
        if err then
          vim.cmd("echo 'Error: " .. err .. "'")
        end
      end
    end
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
