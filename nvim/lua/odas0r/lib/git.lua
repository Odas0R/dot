local M = {}

local function systemlist(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

function M.root(start)
  start = start and start ~= "" and start or vim.fn.getcwd()
  local out = systemlist({ "git", "-C", start, "rev-parse", "--show-toplevel" })
  return out and out[1] or nil
end

return M
