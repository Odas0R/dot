local keymap = vim.keymap.set

-- Checkbox
keymap("x", "<leader>x", function()
  return require("odas0r/checkbox").toggle()
end, { silent = true })

keymap("v", "<leader>x", function()
  return require("odas0r/checkbox").toggle_many()
end, { silent = true })
