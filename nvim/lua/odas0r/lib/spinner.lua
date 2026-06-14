local M = {}

function M.start(message)
  local frames = { "|", "/", "-", "\\" }
  local i = 1
  local timer = vim.uv.new_timer()

  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      vim.api.nvim_echo({ { message .. " " .. frames[i] } }, false, {})
      i = i % #frames + 1
    end)
  )

  return timer
end

return M
