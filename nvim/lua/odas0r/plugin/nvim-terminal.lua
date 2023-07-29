local Utils = require("odas0r.utils")

local M = {}

M.keys = function()
  return {
    {
      "<leader>t",
      "<cmd>lua terminal:toggle()<cr>",
      mode = { "n", "t" },
      desc = "Toggle terminal",
      silent = true,
    },
  }
end

M.init = function()
  -- -------------------------------------------------
  -- Keymaps
  -- -------------------------------------------------
  Utils.map("t", "<Esc>", "<C-\\><C-n>", { silent = true })
  Utils.map("t", "<C-v><Esc>", "<Esc>", { silent = true })

  -- -------------------------------------------------
  -- Autocmds
  -- -------------------------------------------------
  Utils.autocmd("BufReadPre", {
    pattern = "*",
    group = Utils.augroup("terminal"),
    callback = function()
      vim.cmd([[
    lua terminal:close()
  ]])
    end,
  })
  Utils.autocmd("BufWinEnter", {
    pattern = "*",
    group = Utils.augroup("terminal"),
    callback = function()
      vim.cmd([[
    lua terminal:close()
  ]])
    end,
  })
  Utils.autocmd("TermOpen", {
    pattern = "*",
    group = Utils.augroup("terminal"),
    callback = function()
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.cursorline = false
    end,
  })
  Utils.autocmd("TermLeave", {
    pattern = "*",
    group = Utils.augroup("terminal"),
    callback = function()
      vim.cmd([[
      stopinsert
    ]])
    end,
  })
  Utils.autocmd("TermClose", {
    pattern = "*",
    group = Utils.augroup("terminal"),
    callback = function()
      vim.cmd([[
    if (expand('<afile>') !~ "fzf") && (expand('<afile>') !~ "ranger") && (expand('<afile>') !~ "coc") |
      call nvim_input('<CR>')  |
    endif
  ]])
    end,
  })
end

M.config = function()
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
end

return M
