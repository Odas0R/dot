local keymap = vim.keymap.set
local refactor = require("refactor")

keymap('v', '<C-n>', function ()
  refactor.selected_to_new_file()
end, { noremap = true, silent = true })
