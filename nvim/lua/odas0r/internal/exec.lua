local Utils = require("odas0r.utils")

local group = Utils.augroup("Playground_Exec")

Utils.autocmd("FileType", {
  pattern = { "*.sh", "sh", "bash", "*.bash" },
  group = group,
  callback = function()
    Utils.map("x", "<leader>r", "yPgv:!bash<CR>", { buffer = true })
  end,
})

Utils.autocmd("FileType", {
  pattern = { "*.sql", "sql" },
  group = group,
  callback = function()
    Utils.map("x", "<leader>r", ":DB<CR>", { buffer = true })
    Utils.map("n", "<leader>rp", "vap:DB<CR>", { buffer = true })
  end,
})

Utils.autocmd("FileType", {
  pattern = { "lua" },
  group = group,
  callback = function()
    Utils.map("x", "<leader>r", function()
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

      -- join the lines by ; and execute them using vim.cmd("lua " .. cmd)
      local cmd = table.concat(lines, ";")
      vim.cmd("lua " .. cmd)
    end, { buffer = true })
    Utils.map("n", "<leader>rp", function()
      return vim.cmd("echo 'not supported'")
    end, { buffer = true })
  end,
})
