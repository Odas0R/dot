local api = vim.api

local states = {
  unchecked = " ",
  checked = "x",
}

local function toggle()
  local current_line = api.nvim_get_current_line()
  local is_checked = current_line:match("%[" .. states.checked .. "%]")

  if is_checked then
    current_line = current_line:gsub("%[" .. states.checked .. "%]", "%[" .. states.unchecked .. "%]")
  else
    current_line = current_line:gsub("%[" .. states.unchecked .. "%]", "%[" .. states.checked .. "%]")
  end

  api.nvim_set_current_line(current_line)
end

-- Utils

local function get_visual_selection()
  local s_start = vim.fn.getpos("'<")
  local s_end = vim.fn.getpos("'>")
  local n_lines = math.abs(s_end[2] - s_start[2]) + 1
  local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
  lines[1] = string.sub(lines[1], s_start[3], -1)
  if n_lines == 1 then
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
  else
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
  end
  return table.concat(lines, "\n")
end

local function toggle_many()
  local selected_todos = get_visual_selection()
  print(selected_todos)
end

return {
  toggle = toggle,
  toggle_many = toggle_many,
}
