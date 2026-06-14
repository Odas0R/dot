local Window = require("odas0r.lib.window")

local M = {}

local origins = {}
local close_autocmds = {}

local function info_for(win)
  local ok, info = pcall(vim.fn.getwininfo, win)
  if not ok then
    return nil
  end
  return info and info[1] or nil
end

function M.is_window(win)
  local info = info_for(win)
  return info and info.loclist == 1 or false
end

function M.window_title(win)
  local info = info_for(win)
  if not info or info.loclist ~= 1 then
    return nil
  end

  local variables = info.variables or {}
  return variables.quickfix_title
end

function M.find(title)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if M.is_window(win) and (not title or M.window_title(win) == title) then
      return win
    end
  end
  return nil
end

function M.is_open(title)
  return M.find(title) ~= nil
end

local function owner_for_loclist_window(win)
  local ok, loclist = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.getloclist(0, { filewinid = 0 })
  end)
  if ok and type(loclist) == "table" and loclist.filewinid ~= 0 then
    return loclist.filewinid
  end
  return nil
end

function M.owner(win)
  win = win or vim.api.nvim_get_current_win()
  if M.is_window(win) then
    return owner_for_loclist_window(win) or win
  end
  return win
end

local function unwatch_close(title)
  if close_autocmds[title] then
    pcall(vim.api.nvim_del_autocmd, close_autocmds[title])
    close_autocmds[title] = nil
  end
end

local function watch_close(title, win)
  unwatch_close(title)

  close_autocmds[title] = vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      close_autocmds[title] = nil
      vim.schedule(function()
        Window.restore(origins[title])
        origins[title] = nil
      end)
    end,
  })
end

function M.close(title)
  local win = M.find(title)
  if not win then
    return false
  end

  local current = vim.api.nvim_get_current_win()
  local closing_from_loclist = current == win
  local current_state = not closing_from_loclist and Window.save(current) or nil

  unwatch_close(title)
  pcall(vim.api.nvim_win_close, win, true)

  if closing_from_loclist then
    Window.restore(origins[title])
  else
    Window.restore(current_state)
  end
  origins[title] = nil

  return true
end

function M.open(opts)
  opts = opts or {}
  local title = assert(opts.title, "loclist title is required")
  local items = opts.items or {}

  local current = vim.api.nvim_get_current_win()
  if not M.is_window(current) then
    origins[title] = Window.save(current)
  end

  local win = M.find(title)
  local owner = win and owner_for_loclist_window(win) or M.owner(current)
  if not owner or not vim.api.nvim_win_is_valid(owner) then
    owner = current
  end

  vim.fn.setloclist(owner, {}, "r", {
    title = title,
    items = items,
  })

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  else
    vim.api.nvim_set_current_win(owner)
    vim.cmd("botright lopen")
    if opts.height then
      local height = type(opts.height) == "function" and opts.height(#items)
        or opts.height
      pcall(vim.cmd, ("resize %d"):format(height))
    end
  end

  win = M.find(title) or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  watch_close(title, win)

  return buf, win
end

function M.toggle(opts)
  if M.is_open(opts.title) then
    return M.close(opts.title)
  end
  return M.open(opts)
end

return M
