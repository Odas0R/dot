local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd

keymap("n", "<leader>a", function()
  require("harpoon.mark").add_file()
end, { silent = true })

keymap("n", "<C-e>", function()
  require("harpoon.ui").toggle_quick_menu()
end, { silent = true })

keymap("n", "<leader>1", function()
  vim.cmd([[
    lua terminal:close()
  ]])
  require("harpoon.ui").nav_file(1)
end, { silent = true })

keymap("t", "<leader>2", function()
  vim.cmd([[
    lua terminal:close()
  ]])
  require("harpoon.ui").nav_file(2)
end, { silent = true })

keymap("n", "<leader>3", function()
  vim.cmd([[
    lua terminal:close()
  ]])
  require("harpoon.ui").nav_file(3)
end, { silent = true })

keymap("t", "<leader>4", function()
  vim.cmd([[
    lua terminal:close()
  ]])
  require("harpoon.ui").nav_file(4)
end, { silent = true })

autocmd("FileType", {
  pattern = "harpoon",
  callback = function()
    vim.opt_local.cursorline = true
  end,
})
