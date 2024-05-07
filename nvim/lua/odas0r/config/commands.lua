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
