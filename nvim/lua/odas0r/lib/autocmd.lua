local M = {}

function M.group(name, opts)
  opts = opts or { clear = true }
  return vim.api.nvim_create_augroup("config_" .. name, opts)
end

function M.create(event, opts)
  return vim.api.nvim_create_autocmd(event, opts)
end

return M
