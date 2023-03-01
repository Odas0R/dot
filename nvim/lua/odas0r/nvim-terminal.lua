local Terminal = require("nvim-terminal.terminal")
local Window = require("nvim-terminal.window")

local window = Window:new({
  position = "botright",
  split = "sp",
  width = 100,
  height = 35,
})

-- modify the default terminal
terminal = Terminal:new(window)
