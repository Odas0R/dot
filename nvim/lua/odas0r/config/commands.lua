local Utils = require("odas0r.utils")

Utils.cmd("BufClose", function()
  local current_buffer = vim.fn.bufnr("%")
  local last_buffer = vim.fn.bufnr("$")
  local window_count = vim.fn.winnr("$")

  -- Get a list of buffers that are displayed in windows
  local displayed_buffers = {}
  for i = 1, window_count do
    local win_buf = vim.fn.winbufnr(i)
    displayed_buffers[win_buf] = true
  end

  -- Function to close buffers within a range
  local function close_buffers(start, end_)
    for bufnr = start, end_ do
      if not displayed_buffers[bufnr] and vim.fn.buflisted(bufnr) == 1 then
        vim.cmd("silent! bd " .. bufnr)
      end
    end
  end

  -- Close buffers before the current buffer
  if current_buffer > 1 then
    close_buffers(1, current_buffer - 1)
  end

  -- Close buffers after the current buffer
  if current_buffer < last_buffer then
    close_buffers(current_buffer + 1, last_buffer)
  end
end, {
  nargs = 0,
})
