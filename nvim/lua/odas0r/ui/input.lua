local M = {}

local fallback_input = vim.ui.input

local function clamp(value, min, max)
  if value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
end

local function popup_input(opts, on_confirm)
  opts = opts or {}
  on_confirm = on_confirm or function() end

  if #vim.api.nvim_list_uis() == 0 then
    fallback_input(opts, on_confirm)
    return
  end

  local columns = vim.o.columns
  local lines = vim.o.lines
  if columns < 20 or lines < 5 then
    fallback_input(opts, on_confirm)
    return
  end

  local prompt = vim.trim(opts.prompt or "Input")
  if prompt == "" then
    prompt = "Input"
  end

  local default = opts.default or ""
  local width = clamp(math.max(#prompt + 4, #default + 2, 44), 20, columns - 8)
  local row = math.floor((lines - 3) / 2)
  local col = math.floor((columns - width) / 2)

  local ok_buf, buf = pcall(vim.api.nvim_create_buf, false, true)
  if not ok_buf then
    fallback_input(opts, on_confirm)
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true

  local ok_win, win = pcall(vim.api.nvim_open_win, buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = 1,
    border = "rounded",
    style = "minimal",
    title = " " .. prompt .. " ",
    title_pos = "left",
  })

  if not ok_win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    fallback_input(opts, on_confirm)
    return
  end

  vim.wo[win].cursorline = true
  vim.wo[win].winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder"
  vim.api.nvim_win_set_cursor(win, { 1, #default })

  local done = false
  local function close(value)
    if done then
      return
    end
    done = true

    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end

    on_confirm(value)
  end

  local function confirm()
    local value = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    close(value)
  end

  vim.keymap.set({ "n", "i" }, "<cr>", confirm, {
    buffer = buf,
    desc = "Confirm input",
    nowait = true,
  })

  vim.keymap.set({ "n", "i" }, "<esc>", function()
    close(nil)
  end, {
    buffer = buf,
    desc = "Cancel input",
    nowait = true,
  })

  vim.keymap.set({ "n", "i" }, "<c-c>", function()
    close(nil)
  end, {
    buffer = buf,
    desc = "Cancel input",
    nowait = true,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if not done then
        done = true
        on_confirm(nil)
      end
    end,
  })

  vim.cmd.startinsert()
end

function M.input(opts, on_confirm)
  popup_input(opts, on_confirm)
end

return M
