-- TODO: Need to add multi visual support
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

return {
  toggle = toggle,
}
