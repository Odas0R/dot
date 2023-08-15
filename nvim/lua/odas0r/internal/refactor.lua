local Utils = require("odas0r.utils")

local selected_to_new_file = function()
  local buf = vim.api.nvim_get_current_buf()

  local pos_cursor = vim.fn.getpos(".")
  local pos = vim.fn.getpos("v")

  local start_line = pos[2]
  local end_line = pos_cursor[2]

  if end_line < start_line then
    local t_end_line = start_line
    local t_start_line = end_line

    start_line = t_start_line
    end_line = t_end_line
  end

  -- get the selected text from the start_line to end_line
  local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, true)

  -- set the current working directory to the directory of the current buffer
  local original_cwd = vim.fn.getcwd()
  local buf_path = vim.fn.expand("%:p:h")

  -- get the file extension and type of the current buffer
  local file_extension = vim.fn.expand("%:e") ~= "" and "." .. vim.fn.expand("%:e") or ""

  local file_type = vim.api.nvim_buf_get_option(buf, "filetype")

  vim.cmd("cd " .. buf_path)

  Utils.input({ prompt = "New file name: ", completion = "file" }, function(input)
    -- input is nil when user aborts
    if input == nil then
      return
    end

    local empty_input = input == ""
    local file_name = empty_input and "Untitled" .. file_extension or input
    local file_path = buf_path .. "/" .. file_name

    vim.cmd("cd " .. original_cwd)

    -- delete the selected lines
    vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, true, {})

    -- create a new buffer with vsplit
    vim.cmd("rightbelow vnew")

    -- get the new buffer ID
    local new_buf = vim.api.nvim_get_current_buf()

    -- set the filename
    vim.api.nvim_buf_set_name(new_buf, file_path)
    vim.api.nvim_buf_set_lines(new_buf, 0, -1, true, lines)
    vim.api.nvim_buf_set_option(new_buf, "filetype", file_type)
  end)
end

Utils.map("v", "<C-n>", function()
  selected_to_new_file()
end, { noremap = true, silent = true })
