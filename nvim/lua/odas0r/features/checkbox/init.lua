local map = require("odas0r.lib.keymap")

local M = {}

local checked_character = "x"

local states = {
  unchecked = "%[ %]",
  checked = "%[" .. checked_character .. "]",
}

local function line_contains_an_unchecked_checkbox(line)
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

function M.toggle()
  local bufnr = vim.api.nvim_buf_get_number(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_line = cursor[1] - 1
  local current_line = vim.api.nvim_buf_get_lines(
    bufnr,
    start_line,
    start_line + 1,
    false
  )[1] or ""

  local new_line = ""
  if line_contains_an_unchecked_checkbox(current_line) then
    new_line = checkbox.check(current_line)
  else
    new_line = checkbox.uncheck(current_line)
  end

  vim.api.nvim_buf_set_lines(
    bufnr,
    start_line,
    start_line + 1,
    false,
    { new_line }
  )
  vim.api.nvim_win_set_cursor(0, cursor)
end

function M.toggle_many()
  local bufnr = vim.api.nvim_buf_get_number(0)
  local cursor = vim.api.nvim_win_get_cursor(0)

  local pos_cursor = vim.fn.getpos(".")
  local pos = vim.fn.getpos("v")

  local start_line = pos[2]
  local end_line = pos_cursor[2]

  if end_line < start_line then
    start_line, end_line = end_line, start_line
  end

  local lines =
    vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_lines = {}

  for _, line in ipairs(lines) do
    if line_contains_an_unchecked_checkbox(line) then
      table.insert(new_lines, checkbox.check(line))
    else
      table.insert(new_lines, checkbox.uncheck(line))
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
  vim.api.nvim_win_set_cursor(0, cursor)
end

function M.setup(opts)
  opts = opts or {}
  local keymap = opts.keymap or "<leader>x"

  map("n", keymap, M.toggle, { silent = true, desc = "Toggle checkbox" })
  map("v", keymap, M.toggle_many, {
    silent = false,
    desc = "Toggle selected checkboxes",
  })
end

return M
