local keymap = vim.keymap.set

keymap("n", "<leader>bl", function()
  return require("telescope.builtin").buffers()
end, { silent = true })
keymap("n", "<C-p>", function()
  return require("telescope.builtin").find_files()
end, { silent = true })
keymap("n", "<C-g>", function()
  return require("telescope.builtin").live_grep()
end, { silent = true })

keymap("n", "<leader>fe", function()
  return require("odas0r.telescope").search_repos()
end, { silent = true })
keymap("n", "<leader>fg", function()
  return require("odas0r.telescope").search_repos_grep()
end, { silent = true })
