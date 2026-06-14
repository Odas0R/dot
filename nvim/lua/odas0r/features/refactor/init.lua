local map = require("odas0r.lib.keymap")

local M = {}

function M.selected_to_new_file()
  local buf = vim.api.nvim_get_current_buf()

  local pos_cursor = vim.fn.getpos(".")
  local pos = vim.fn.getpos("v")

  local start_line = pos[2]
  local end_line = pos_cursor[2]

  if end_line < start_line then
    start_line, end_line = end_line, start_line
  end

  -- get the selected text from the start_line to end_line
  local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, true)

  -- set the current working directory to the directory of the current buffer
  local original_cwd = vim.fn.getcwd()
  local buf_path = vim.fn.expand("%:p:h")

  -- get the file extension and type of the current buffer
  local file_extension = vim.fn.expand("%:e") ~= ""
      and "." .. vim.fn.expand("%:e")
    or ""

  local file_type = vim.api.nvim_get_option_value("filetype", { buf = buf })

  vim.cmd("cd " .. vim.fn.fnameescape(buf_path))

  vim.ui.input(
    { prompt = "New file name: ", completion = "file" },
    function(input)
      -- input is nil when user aborts
      if input == nil then
        vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
        return
      end

      local empty_input = input == ""
      local file_name = empty_input and "Untitled" .. file_extension or input
      local file_path = buf_path .. "/" .. file_name

      vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

      -- delete the selected lines
      vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, true, {})

      -- create a new buffer with vsplit
      vim.cmd("rightbelow vnew")

      -- get the new buffer ID
      local new_buf = vim.api.nvim_get_current_buf()

      -- set the filename
      vim.api.nvim_buf_set_name(new_buf, file_path)
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, true, lines)
      vim.api.nvim_set_option_value("filetype", file_type, { buf = new_buf })
    end
  )
end

function M.setup(opts)
  opts = opts or {}
  local keymap = opts.keymap or "<C-n>"

  map("v", keymap, M.selected_to_new_file, {
    noremap = true,
    silent = true,
    desc = "Extract selection to new file",
  })
end

return M
