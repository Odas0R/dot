local M = {
  _terminal = nil,
}

M.setup = function(opts)
  local Terminal = require("odas0r.plugin.terminal.terminal")
  local Window = require("odas0r.plugin.terminal.window")

  local window = Window:new(vim.tbl_deep_extend("force", {
    position = "botright",
    split = "sp",
    width = 100,
    height = 35,
  }, (opts and opts.window) or {})) -- Fixed the optional chaining

  M._terminal = Terminal:new(window)
end

local function get_terminal()
  if not M._terminal then
    M.setup({})
  end
  return M._terminal
end

return {
  toggle = function()
    get_terminal():toggle()
  end,

  config = function(_, opts)
    M.setup(opts)
  end,

  -- Load these modules when the plugin loads
  dependencies = {},

  keys = {
    {
      "<leader>t",
      function()
        require("odas0r.plugin.terminal").toggle()
      end,
      mode = { "n", "t" },
      desc = "Toggle terminal",
    },
    {
      "<Esc>",
      "<C-\\><C-n>",
      mode = "t",
      desc = "Exit terminal mode",
    },
    {
      "<C-v><Esc>",
      "<Esc>",
      mode = "t",
      desc = "Send Escape to terminal",
    },
  },

  init = function()
    local Util = require("odas0r.utils")

    Util.autocmd("BufReadPre", {
      pattern = "*",
      group = Util.augroup("terminal"),
      callback = function()
        vim.cmd([[
    lua terminal:close()
  ]])
      end,
    })
    Util.autocmd("BufWinEnter", {
      pattern = "*",
      group = Util.augroup("terminal"),
      callback = function()
        vim.cmd([[
    lua terminal:close()
  ]])
      end,
    })
    Util.autocmd("TermOpen", {
      pattern = "*",
      group = Util.augroup("terminal"),
      callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.cursorline = false
      end,
    })
    Util.autocmd("TermLeave", {
      pattern = "*",
      group = Util.augroup("terminal"),
      callback = function()
        vim.cmd([[
      stopinsert
    ]])
      end,
    })
    Util.autocmd("TermClose", {
      pattern = "*",
      group = Util.augroup("terminal"),
      callback = function()
        vim.cmd([[
    if (expand('<afile>') !~ "fzf") && (expand('<afile>') !~ "ranger") && (expand('<afile>') !~ "coc") |
      call nvim_input('<CR>')  |
    endif
  ]])
      end,
    })
  end,
}
