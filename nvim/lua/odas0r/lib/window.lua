local M = {}

function M.save(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  local ok, view = pcall(vim.api.nvim_win_call, win, vim.fn.winsaveview)
  if not ok then
    view = vim.fn.winsaveview()
  end

  return {
    win = win,
    view = view,
  }
end

function M.restore(state)
  if not state or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return false
  end

  vim.api.nvim_set_current_win(state.win)
  if state.view then
    pcall(vim.fn.winrestview, state.view)
  end
  return true
end

return M
