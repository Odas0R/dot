local M = {
  _terminal = nil,
  config = nil,
}

local function get_terminal()
  if not M._terminal then
    M.setup({})
  end
  return M._terminal
end

M.setup = function(opts)
  local Terminal = require("odas0r.internal.terminal.terminal")
  local Window = require("odas0r.internal.terminal.window")
  local DefaultConfig = require("odas0r.internal.terminal.config")

  -- Merge defaults with user options
  M.config = vim.tbl_deep_extend("force", DefaultConfig, opts or {})

  local window = Window:new(M.config.window)
  M._terminal = Terminal:new(window)

  -- Setup Keymaps
  if not M.config.disable_default_keymaps then
    local set_keymap = vim.keymap.set
    local opts_desc = { silent = true }

    -- Toggle

    if M.config.toggle_keymap then
      set_keymap(
        "n",
        M.config.toggle_keymap,
        M.toggle,
        vim.tbl_extend("force", opts_desc, { desc = "Toggle Terminal" })
      )

      set_keymap(
        "t",
        M.config.toggle_keymap,
        M.toggle,
        vim.tbl_extend("force", opts_desc, { desc = "Toggle Terminal" })
      )
    end

    -- Escape to exit terminal mode

    if M.config.esc_to_exit then
      set_keymap("t", "<Esc>", "<C-\\><C-n>", vim.tbl_extend("force", opts_desc, { desc = "Exit Terminal Mode" }))

      set_keymap("t", "<C-v><Esc>", "<Esc>", vim.tbl_extend("force", opts_desc, { desc = "Send Escape to Terminal" }))
    end

    -- Resize

    if M.config.increase_height_keymap then
      set_keymap("n", M.config.increase_height_keymap, function()
        get_terminal().window:change_height(M.config.window_height_change_amount)
      end, vim.tbl_extend("force", opts_desc, { desc = "Increase Terminal Height" }))
    end

    if M.config.decrease_height_keymap then
      set_keymap("n", M.config.decrease_height_keymap, function()
        get_terminal().window:change_height(-M.config.window_height_change_amount)
      end, vim.tbl_extend("force", opts_desc, { desc = "Decrease Terminal Height" }))
    end

    if M.config.increase_width_keymap then
      set_keymap("n", M.config.increase_width_keymap, function()
        get_terminal().window:change_width(M.config.window_width_change_amount)
      end, vim.tbl_extend("force", opts_desc, { desc = "Increase Terminal Width" }))
    end

    if M.config.decrease_width_keymap then
      set_keymap("n", M.config.decrease_width_keymap, function()
        get_terminal().window:change_width(-M.config.window_width_change_amount)
      end, vim.tbl_extend("force", opts_desc, { desc = "Decrease Terminal Width" }))
    end
  end

  -- Auto-close terminal on navigation

  if M.config.close_on_nav then
    local grp = vim.api.nvim_create_augroup("TerminalNav", { clear = true })

    local function close_term()
      if M._terminal and M._terminal.window:is_valid() then
        M.close()
      end
    end

    vim.api.nvim_create_autocmd({ "BufReadPre", "BufWinEnter" }, {
      group = grp,
      pattern = "*",
      callback = close_term,
    })
  end

  vim.api.nvim_create_user_command("T", function(cmd_opts)
    M.execute(cmd_opts.args)
  end, {
    nargs = "*",
    complete = "file",
    desc = "Execute command in terminal",
  })
end

M.toggle = function()
  get_terminal():toggle()
end

M.open = function()
  get_terminal():open()
end

M.close = function()
  if M._terminal then
    M._terminal:close()
  end
end

M.execute = function(cmd)
  local expanded_cmd = vim.fn.expandcmd(cmd)
  get_terminal():send(expanded_cmd)
end

return M
