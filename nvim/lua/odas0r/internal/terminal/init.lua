local M = {
  _terminal = nil,
}

local function get_terminal()
  if not M._terminal then
    M.setup({})
  end
  return M._terminal
end

M.setup = function(opts)
  local Terminal = require("odas0r.internal.terminal.terminal")
  local Window = require("odas0r.internal.terminal.window")

  local window = Window:new(vim.tbl_deep_extend("force", {
    position = "botright",
    split = "sp",
    width = 100,
    height = 35,
  }, (opts and opts.window) or {})) -- Fixed the optional chaining

  M._terminal = Terminal:new(window)
end

M.toggle = function()
	get_terminal():toggle()
end

M.open = function()
	get_terminal():open()
end

return M
