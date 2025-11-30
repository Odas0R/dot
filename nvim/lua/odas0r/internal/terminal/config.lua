local config = {
  window = {
    -- Do `:h :botright` for more information
    position = "botright",

    -- Do `:h split` for more information
    split = "sp",

    -- Height of the terminal
    height = 25,
  },

  -- keymap to disablesb all the default keymaps
  disable_default_keymaps = false,

  -- keymap to toggle open and close terminal window
  toggle_keymap = "<leader>t",

  -- increase the window width by when you hit the keymap
  window_height_change_amount = 2,

  -- increase the window height by when you hit the keymap
  window_width_change_amount = 2,

  -- keymap to increase the window width
  increase_width_keymap = "<leader><leader>+",

  -- keymap to decrease the window width
  decrease_width_keymap = "<leader><leader>-",

  -- keymap to increase the window height
  increase_height_keymap = "<leader>+",

  -- keymap to decrease the window height
  decrease_height_keymap = "<leader>-",

  -- Map <Esc> to <C-\><C-n> to exit terminal mode
  esc_to_exit = true,

  -- Close the terminal window when opening a new file or navigating to a new window
  close_on_nav = true,

  terminals = {
    -- keymaps to open nth terminal
    { keymap = "<leader>1" },
    { keymap = "<leader>2" },
    { keymap = "<leader>3" },
    { keymap = "<leader>4" },
    { keymap = "<leader>5" },
  },
}

return config
