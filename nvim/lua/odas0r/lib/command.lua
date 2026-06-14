local M = {}

function M.create(name, callback, opts)
  return vim.api.nvim_create_user_command(name, callback, opts or {})
end

return M
