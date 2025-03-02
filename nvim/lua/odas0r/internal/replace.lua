local M = {}
local Job = require("plenary.job")
local utils = require("odas0r.utils")

local function parse_patterns(args)
  local pattern, replacement
  -- "pattern" "replacement" or 'pattern' 'replacement'
  if args:match("^['\"].-['\"]%s+['\"].-['\"]$") then
    pattern, replacement = args:match("^['\"](.-)['\"]%s+['\"](.-)['\"]$")
  else
    -- separated format: pattern replacement
    pattern, replacement = args:match("^(%S+)%s+(%S+)$")
  end

  return pattern, replacement
end

local function escape_for_shell(str)
  return str:gsub("/", "\\/"):gsub("'", "'\\''")
end

local function build_command(pattern, replacement)
  local escaped_pattern = escape_for_shell(pattern)
  local escaped_replacement = escape_for_shell(replacement)

  return string.format(
    "rg --files --glob '!node_modules/**' --glob '!.git/**' --glob '!dist/**' --glob '!build/**' | "
      .. "xargs -r sed -i 's/%s/%s/g'",
    escaped_pattern,
    escaped_replacement
  )
end

-- get unique words from current buffer for autocomplete
local function get_unique_words()
  local words = {}
  local unique_words = {}
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for _, line in ipairs(lines) do
    for word in line:gmatch("%S+") do
      if not words[word] then
        words[word] = true
        table.insert(unique_words, word)
      end
    end
  end
  return unique_words
end

local function autocomplete(arg_lead, cmd_line, cursor_pos)
  local words = get_unique_words()
  local matches = {}

  for _, word in ipairs(words) do
    if word:find("^" .. arg_lead) then
      table.insert(matches, word)
    end
  end

  return matches
end

function M.replace(args)
  local pattern, replacement = parse_patterns(args)

  if not pattern or not replacement then
    vim.notify("Usage: Replace pattern replacement", vim.log.levels.ERROR)
    return
  end

  -- save modified buffers
  vim.cmd("silent! wall")

  local command = build_command(pattern, replacement)
  local animation = utils.loading_animation("Replacing across project...")

  -- execute the command
  Job
    :new({
      command = "bash",
      args = { "-c", command },
      on_exit = function(j, code)
        animation:stop()

        if code ~= 0 then
          vim.notify("Error during replacement operation", vim.log.levels.ERROR)
          return
        end

        -- refresh buffers and notify user
        vim.schedule(function()
          vim.cmd("checktime")
          vim.notify("Replaced '" .. pattern .. "' with '" .. replacement .. "' across project", vim.log.levels.INFO)
        end)
      end,
      on_stderr = function(_, data)
        if data and data ~= "" then
          print("Error: " .. data)
        end
      end,
    })
    :start()
end

-- Create the Replace command
utils.cmd("Replace", function(opts)
  M.replace(opts.fargs[1])
end, {
  nargs = 1,
  complete = autocomplete,
  desc = "Replace pattern with replacement across project files",
})

return M
