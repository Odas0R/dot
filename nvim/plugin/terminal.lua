local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd

keymap({ "n", "t" }, "<leader>t", function()
  vim.cmd([[
    lua terminal:toggle()
  ]])
end, { silent = true })

keymap("t", "<Esc>", "<C-\\><C-n>", { silent = true })
keymap("t", "<C-v><Esc>", "<Esc>", { silent = true })

autocmd("BufReadPre", {
  pattern = "*",
  callback = function()
    vim.cmd([[
    lua terminal:close()
  ]])
  end,
})

autocmd("BufWinEnter", {
  pattern = "*",
  callback = function()
    vim.cmd([[
    lua terminal:close()
  ]])
  end,
})

autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
  end,
})

autocmd("TermLeave", {
  pattern = "*",
  callback = function()
    vim.cmd([[
      stopinsert
    ]])
  end,
})

autocmd("TermClose", {
  pattern = "*",
  callback = function()
    vim.cmd([[
    if (expand('<afile>') !~ "fzf") && (expand('<afile>') !~ "ranger") && (expand('<afile>') !~ "coc") |
      call nvim_input('<CR>')  |
    endif
  ]])
  end,
})
