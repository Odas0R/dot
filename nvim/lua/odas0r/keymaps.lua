local map = require("odas0r.utils").map

-- better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })

-- Window management
map("n", "<C-w>\\", ":vsplit<CR> | :wincmd l<CR>")
map("n", "<C-w>-", ":split<CR> | :wincmd b<CR>")

-- Move Between Tabs
map("n", "gt", ":tabnext<CR>")
map("n", "gT", ":tabprev<CR>")
map("n", "gN", ":tabnew<CR>")

map("n", "<leader>F", ":GoTestFunc<CR>")
map("n", "<leader>T", ":GoTestFile<CR>")

-- Trial: close popups, locallist, quickfix
map("n", "<leader>q", ":cclose<CR>")

-- Move Between buffers
-- map("n", "<BS>", ":bp<CR>")
-- map("n", "<C-BS>", ":bn<CR>")

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map(
  "n",
  "<C-Left>",
  "<cmd>vertical resize +2<cr>",
  { desc = "Decrease window width" }
)
map(
  "n",
  "<C-Right>",
  "<cmd>vertical resize -2<cr>",
  { desc = "Increase window width" }
)

map("n", "<leader>vu", ":so " .. vim.env.HOME .. "/.config/nvim/init.lua<CR>")
map("n", "<C-l>", ":nohl<CR>")
map("n", "<ESC>", ":nohl<CR>")
map("n", "<leader>s", ":set spell!<CR>")
-- map("n", "<leader>p", ":set paste!<CR>")

-- Quickfix
map("n", "<C-j>", ":cnext<CR>")
map("n", "<C-k>", ":cprev<CR>")

-- Clear search, diff update and redraw
-- taken from runtime/lua/_editor.lua
map(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "Redraw / clear hlsearch / diff update" }
)

map({ "n", "x" }, "gw", "*N", { desc = "Search word under cursor" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map(
  "n",
  "n",
  "'Nn'[v:searchforward]",
  { expr = true, desc = "Next search result" }
)
map(
  "x",
  "n",
  "'Nn'[v:searchforward]",
  { expr = true, desc = "Next search result" }
)
map(
  "o",
  "n",
  "'Nn'[v:searchforward]",
  { expr = true, desc = "Next search result" }
)
map(
  "n",
  "N",
  "'nN'[v:searchforward]",
  { expr = true, desc = "Prev search result" }
)
map(
  "x",
  "N",
  "'nN'[v:searchforward]",
  { expr = true, desc = "Prev search result" }
)
map(
  "o",
  "N",
  "'nN'[v:searchforward]",
  { expr = true, desc = "Prev search result" }
)

-- Add undo break-points
-- map("i", ".", ".<c-g>u")
-- map("i", ";", ";<c-g>u")

-- better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Remap § to output < and ± to output >
-- In ducky keyboard layout these keys are incorrectly mapped, so... this is a workaround
--
-- ## 1. For Typing ##
-- In Insert and Command-line mode, swap the characters.
vim.keymap.set({ "i", "c" }, "§", "<", { noremap = true })
vim.keymap.set({ "i", "c" }, "±", ">", { noremap = true })

-- ## 2. For Normal Mode ##
-- Map the DOUBLE-PRESS sequence directly to the indent commands.
-- This avoids any timing issues.
vim.keymap.set("n", "§§", "<<", { noremap = true, desc = "Un-indent line" })
vim.keymap.set("n", "±±", ">>", { noremap = true, desc = "Indent line" })

-- ## 3. For Visual Mode ##
-- A SINGLE-PRESS on a selection will indent/un-indent.
vim.keymap.set("v", "§", "<", { noremap = true, desc = "Un-indent selection" })
vim.keymap.set("v", "±", ">", { noremap = true, desc = "Indent selection" })
