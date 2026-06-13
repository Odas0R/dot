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

local function strwidth(value)
  return vim.fn.strdisplaywidth(value or "")
end

local function ellipsize(value, max_width)
  if strwidth(value) <= max_width then
    return value
  end

  return vim.fn.strcharpart(value, 0, math.max(max_width - 1, 0)) .. "…"
end

local function number_opt(value)
  if value == nil then
    return nil
  end

  return tonumber(value)
end

local function max_line_width(values)
  local width = 0
  for _, value in ipairs(values) do
    width = math.max(width, strwidth(value))
  end
  return width
end

local function split_default(value, multiline)
  value = tostring(value or "")

  if multiline then
    local parts = vim.split(value, "\n", { plain = true })
    return #parts > 0 and parts or { "" }
  end

  return { value:gsub("\n", " ") }
end

local function apply_highlights()
  local ok, gruvbox = pcall(require, "odas0r.features.gruvbox")
  local colors = ok and gruvbox.colors() or {}

  vim.api.nvim_set_hl(0, "Odas0rInputNormal", {
    fg = colors.fg1,
    bg = "NONE",
  })
  vim.api.nvim_set_hl(0, "Odas0rInputBorder", {
    fg = colors.gray or colors.fg4,
    bg = "NONE",
  })
  vim.api.nvim_set_hl(0, "Odas0rInputTitle", {
    fg = colors.yellow or colors.fg1,
    bg = "NONE",
    bold = true,
  })
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

  local multiline = opts.multiline == true
  local default_lines = split_default(opts.default, multiline)
  local configured_width = number_opt(opts.width)
  local max_available_width = columns - 4
  local min_width =
    clamp(math.floor(number_opt(opts.min_width) or 26), 1, max_available_width)
  local max_width = clamp(
    math.floor(
      number_opt(opts.max_width)
        or (configured_width and max_available_width)
        or (columns * 0.45)
    ),
    min_width,
    max_available_width
  )
  local preferred_width = configured_width
    or math.max(
      strwidth(prompt) + 2,
      max_line_width(default_lines) + 1,
      min_width
    )
  local width = clamp(math.floor(preferred_width), min_width, max_width)

  local max_available_height = math.max(1, lines - 4)
  local height = 1
  if multiline then
    local preferred_height = number_opt(opts.height) or 5
    height = clamp(math.floor(preferred_height), 2, max_available_height)
  end

  local row = math.max(1, math.floor((lines - height) * 0.28))
  local col = math.floor((columns - width) / 2)
  local title = " " .. ellipsize(prompt, width - 2) .. " "

  apply_highlights()

  local ok_buf, buf = pcall(vim.api.nvim_create_buf, false, true)
  if not ok_buf then
    fallback_input(opts, on_confirm)
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, default_lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true

  local ok_win, win = pcall(vim.api.nvim_open_win, buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    title = title,
    title_pos = "center",
  })

  if not ok_win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    fallback_input(opts, on_confirm)
    return
  end

  vim.wo[win].cursorline = false
  vim.wo[win].wrap = multiline
  vim.wo[win].winhighlight = table.concat({
    "NormalFloat:Odas0rInputNormal",
    "FloatBorder:Odas0rInputBorder",
    "FloatTitle:Odas0rInputTitle",
    "CursorLine:Odas0rInputNormal",
  }, ",")
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end

  local last_line = default_lines[#default_lines] or ""
  vim.api.nvim_win_set_cursor(win, { #default_lines, #last_line })

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
    local value
    if multiline then
      value = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    else
      value = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    end
    close(value)
  end

  local function cancel()
    close(nil)
  end

  if multiline then
    vim.keymap.set("n", "<cr>", confirm, {
      buffer = buf,
      desc = "Confirm textarea",
      nowait = true,
    })
    for _, lhs in ipairs({ "<c-s>", "<c-cr>", "<m-cr>" }) do
      vim.keymap.set({ "n", "i" }, lhs, confirm, {
        buffer = buf,
        desc = "Confirm textarea",
        nowait = true,
      })
    end
    for _, lhs in ipairs({ "<esc>", "q" }) do
      vim.keymap.set("n", lhs, cancel, {
        buffer = buf,
        desc = "Cancel textarea",
        nowait = true,
      })
    end
    vim.keymap.set({ "n", "i" }, "<c-c>", cancel, {
      buffer = buf,
      desc = "Cancel textarea",
      nowait = true,
    })
  else
    vim.keymap.set({ "n", "i" }, "<cr>", confirm, {
      buffer = buf,
      desc = "Confirm input",
      nowait = true,
    })
    vim.keymap.set({ "n", "i" }, "<esc>", cancel, {
      buffer = buf,
      desc = "Cancel input",
      nowait = true,
    })
    vim.keymap.set({ "n", "i" }, "<c-c>", cancel, {
      buffer = buf,
      desc = "Cancel input",
      nowait = true,
    })
  end

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

function M.textarea(opts, on_confirm)
  opts = vim.tbl_extend("force", opts or {}, { multiline = true })
  popup_input(opts, on_confirm)
end

return M
