local Utils = require("odas0r.utils")
local checked_character = "x"

local states = {
  unchecked = "%[ %]",
  checked = "%[" .. checked_character .. "]",
}

local line_contains_an_unchecked_checkbox = function(line)
  return line:find(states.unchecked)
end

local checkbox = {
  check = function(line)
    return line:gsub(states.unchecked, states.checked)
  end,
  uncheck = function(line)
    return line:gsub(states.checked, states.unchecked)
  end,
}

local toggle = function()
  local bufnr = vim.api.nvim_buf_get_number(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_line = cursor[1] - 1
  local current_line = vim.api.nvim_buf_get_lines(bufnr, start_line, start_line + 1, false)[1] or ""

  local new_line = ""
  if line_contains_an_unchecked_checkbox(current_line) then
    new_line = checkbox.check(current_line)
  else
    new_line = checkbox.uncheck(current_line)
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line, start_line + 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, cursor)
end

local toggle_many = function()
  local bufnr = vim.api.nvim_buf_get_number(0)
  local cursor = vim.api.nvim_win_get_cursor(0)

  local pos_cursor = vim.fn.getpos(".")
  local pos = vim.fn.getpos("v")

  local start_line = pos[2]
  local end_line = pos_cursor[2]

  if end_line < start_line then
    local t_end_line = start_line
    local t_start_line = end_line
    start_line = t_start_line
    end_line = t_end_line
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_lines = {}

  for _, line in ipairs(lines) do
    if line_contains_an_unchecked_checkbox(line) then
      local new_line = checkbox.check(line)
      table.insert(new_lines, new_line)
    else
      local new_line = checkbox.uncheck(line)
      table.insert(new_lines, new_line)
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
  vim.api.nvim_win_set_cursor(0, cursor)
end

-- Checkbox
Utils.map("n", "<leader>x", function()
  toggle()
end, { silent = true })

Utils.map("v", "<leader>x", function()
  toggle_many()
end, { silent = false })
