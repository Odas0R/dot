local refactor = require("odas0r.refactor.refactor")

local keymap = vim.keymap.set

keymap("v", "<C-n>", function()
  refactor.selected_to_new_file()
end, { noremap = true, silent = true })
