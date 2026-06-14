local autocmd = require("odas0r.lib.autocmd")
local map = require("odas0r.lib.keymap")

local M = {}

local function current_buf(buf)
  return buf and buf ~= 0 and buf or vim.api.nvim_get_current_buf()
end

local function lua_visual_exec()
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

  -- join the lines by ; and execute them using vim.cmd("lua " .. cmd)
  local cmd = table.concat(lines, ";")
  vim.cmd("lua " .. cmd)
end

function M.setup_buffer(buf, filetype)
  buf = current_buf(buf)
  filetype = filetype or vim.api.nvim_get_option_value("filetype", { buf = buf })

  if filetype == "sh" or filetype == "bash" then
    map("x", "<leader>r", "yPgv:!bash<CR>", { buffer = buf })
    return
  end

  if filetype == "sql" then
    map("x", "<leader>r", ":DB<CR>", { buffer = buf })
    map("n", "<leader>rp", "vap:DB<CR>", { buffer = buf })
    return
  end

  if filetype == "lua" then
    map("x", "<leader>r", lua_visual_exec, { buffer = buf })
    map("n", "<leader>rp", function()
      return vim.cmd("echo 'not supported'")
    end, { buffer = buf })
  end
end

function M.setup()
  local group = autocmd.group("Playground_Exec")

  autocmd.create("FileType", {
    pattern = { "sh", "bash", "sql", "lua" },
    group = group,
    callback = function(args)
      M.setup_buffer(args.buf, args.match)
    end,
  })

  M.setup_buffer(0)
end

return M
