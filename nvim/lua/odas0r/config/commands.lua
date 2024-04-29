local Utils = require("odas0r.utils")

Utils.cmd("BufClose", function()
  local current_buffer = vim.fn.bufnr("%")
  local last_buffer = vim.fn.bufnr("$")

  if current_buffer > 1 then
    vim.cmd("silent! " .. "1, " .. current_buffer - 1 .. "bd")
  end

  if current_buffer < last_buffer then
    vim.cmd("silent! " .. current_buffer + 1 .. "," .. last_buffer .. "bd")
  end
end, {
  nargs = 0,
})

Utils.cmd("GoTest", function(tbl_args)
  local test_command = "go test " .. tbl_args.args .. " " .. vim.fn.expand("%")
  local tmux_command = string.format(
    "tmux split-window -h 'cd %s && %s; echo Press Enter to close...; read'",
    vim.fn.getcwd(),
    test_command
  )
  vim.fn.system(tmux_command)
end, {
  nargs = "*", -- 0 or more arguments
})
