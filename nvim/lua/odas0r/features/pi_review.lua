local Input = require("odas0r.ui.input")

local M = {}

local review_comment_input_width = 64
local review_comment_input_height = 7
local review_comments = {}
local next_review_comment_id = 1

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Pi review" })
end

local function systemlist(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

local function git_root(start)
  start = start and start ~= "" and start or vim.fn.getcwd()
  local out = systemlist({ "git", "-C", start, "rev-parse", "--show-toplevel" })
  return out and out[1] or nil
end

local function is_uri(path)
  return path:match("^%w[%w+.-]*://") ~= nil
end

local function path_from_diffview_vars()
  local candidates = {
    "absolute_path",
    "abs_path",
    "path",
    "newpath",
    "oldpath",
    "filename",
  }

  local seen = {}
  local function visit(value)
    if type(value) == "string" then
      if value ~= "" and not is_uri(value) then
        return value
      end
      return nil
    end

    if type(value) ~= "table" or seen[value] then
      return nil
    end
    seen[value] = true

    for _, key in ipairs(candidates) do
      local found = visit(value[key])
      if found then
        return found
      end
    end

    for _, child in pairs(value) do
      local found = visit(child)
      if found then
        return found
      end
    end
  end

  return visit(vim.b.diffview_file) or visit(vim.b.diffview_item)
end

local function current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and not is_uri(name) then
    return name
  end
  return path_from_diffview_vars() or name
end

local function relative_file(root, file)
  if not file or file == "" then
    return nil
  end

  if not vim.startswith(file, "/") and not is_uri(file) then
    return file
  end

  if is_uri(file) then
    return file
  end

  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  file = vim.fn.fnamemodify(file, ":p")
  local prefix = root .. "/"
  if vim.startswith(file, prefix) then
    return file:sub(#prefix + 1)
  end

  return file
end

local function selected_lines(line1, line2)
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  return table.concat(lines, "\n")
end

local function review_root()
  local file = current_file()
  local root_start = file
      and not is_uri(file)
      and vim.fn.fnamemodify(file, ":p:h")
    or vim.fn.getcwd()
  return git_root(root_start)
end

local function json_encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

local function review_bridge()
  local address = vim.env.PI_REVIEW_ADDRESS
  if address and address ~= "" then
    return "tcp", address
  end

  local socket = vim.env.PI_REVIEW_SOCKET
  if socket and socket ~= "" then
    return "pipe", socket
  end

  return nil, nil
end

local function is_review_session()
  local mode, target = review_bridge()
  return mode ~= nil
    and target ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= ""
end

local function send_to_pi(payload)
  local mode, target = review_bridge()
  local token = vim.env.PI_REVIEW_TOKEN

  if not mode or not target or not token or token == "" then
    notify(
      "No live Pi review bridge found. Open Diffview from Pi with /review-diff.",
      vim.log.levels.ERROR
    )
    return false
  end

  payload.token = token
  local ok, encoded = pcall(json_encode, payload)
  if not ok then
    notify(
      "Could not encode review comments: " .. tostring(encoded),
      vim.log.levels.ERROR
    )
    return false
  end

  local connected, chan =
    pcall(vim.fn.sockconnect, mode, target, { rpc = false })
  if not connected or not chan or chan <= 0 then
    notify(
      "Could not connect to Pi review bridge: " .. tostring(chan),
      vim.log.levels.ERROR
    )
    return false
  end

  local sent_ok, sent = pcall(vim.fn.chansend, chan, encoded .. "\n")
  if not sent_ok or sent == 0 then
    pcall(vim.fn.chanclose, chan)
    notify("Could not send review comments to Pi", vim.log.levels.ERROR)
    return false
  end

  pcall(vim.fn.chanclose, chan)
  return true
end

local function review_file_context()
  local file = current_file()
  local root = review_root()
  if not root then
    notify("Not inside a Git repository", vim.log.levels.ERROR)
    return nil
  end

  local rel = relative_file(root, file) or "<unknown>"
  return {
    file = rel,
    filetype = vim.bo.filetype,
  }
end

local function plural(count, singular, plural_word)
  if count == 1 then
    return singular
  end
  return plural_word or (singular .. "s")
end

local function reset_review_comment_ids()
  for index, comment in ipairs(review_comments) do
    comment.id = index
  end
  next_review_comment_id = #review_comments + 1
end

local function add_review_comment(comment)
  comment.id = next_review_comment_id
  next_review_comment_id = next_review_comment_id + 1
  table.insert(review_comments, comment)
  notify(
    ("Added review comment #%d (%d pending)"):format(
      comment.id,
      #review_comments
    )
  )
end

local review_loclist_title = "Pi review comments"
local review_loclist_origin = nil
local review_loclist_close_autocmd = nil

local function truncate(value, max_width)
  if vim.fn.strdisplaywidth(value) <= max_width then
    return value
  end
  return vim.fn.strcharpart(value, 0, math.max(max_width - 1, 0)) .. "…"
end

local function comment_kind(comment)
  return comment.scope == "file" and "file" or "line"
end

local function comment_label(comment)
  return ("#%d [%s] %s"):format(
    comment.id,
    comment_kind(comment),
    comment.location
  )
end

local function comment_summary(comment)
  local summary = vim.trim((comment.comment or ""):gsub("%s+", " "))
  return summary ~= "" and summary or "<empty>"
end

local function pending_payload()
  return {
    scope = "batch",
    comments = vim.deepcopy(review_comments),
  }
end

local function find_comment_by_id(id)
  for _, comment in ipairs(review_comments) do
    if comment.id == id then
      return comment
    end
  end
  return nil
end

local function clear_comment_by_id(id)
  for index, comment in ipairs(review_comments) do
    if comment.id == id then
      table.remove(review_comments, index)
      reset_review_comment_ids()
      return comment
    end
  end
  return nil
end

local function clear_comment_ids(ids)
  local pending = {}
  for _, id in ipairs(ids) do
    pending[id] = true
  end

  local removed = 0
  for index = #review_comments, 1, -1 do
    if pending[review_comments[index].id] then
      table.remove(review_comments, index)
      removed = removed + 1
    end
  end

  if removed > 0 then
    reset_review_comment_ids()
  end

  return removed
end

local function loclist_item_for_comment(comment)
  local item = {
    lnum = comment.line1 or 1,
    col = 1,
    text = ("#%d [%s] — %s"):format(
      comment.id,
      comment_kind(comment),
      truncate(comment_summary(comment), 80)
    ),
  }

  if comment.file and comment.file ~= "" and comment.file ~= "<unknown>" then
    item.filename = comment.file
  end

  return item
end

local function loclist_comment_id_at_line(line)
  local item = vim.fn.getloclist(0)[line]
  if not item then
    return nil
  end

  local id = tostring(item.text or ""):match("^#(%d+)")
  return id and tonumber(id) or nil
end

local function current_loclist_comment_id()
  return loclist_comment_id_at_line(vim.fn.line("."))
end

local function loclist_comment_ids_in_range(line1, line2)
  if line2 < line1 then
    line1, line2 = line2, line1
  end

  local ids = {}
  local seen = {}
  for line = line1, line2 do
    local id = loclist_comment_id_at_line(line)
    if id and not seen[id] then
      seen[id] = true
      table.insert(ids, id)
    end
  end

  return ids
end

local function is_loclist_window(win)
  local info = vim.fn.getwininfo(win)[1]
  return info and info.loclist == 1
end

local function loclist_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local info = vim.fn.getwininfo(win)[1]
    if info and info.loclist == 1 then
      return win, info
    end
  end
  return nil, nil
end

local function loclist_owner_window()
  local ok, info = pcall(vim.fn.getloclist, 0, { filewinid = 0 })
  if
    ok
    and type(info) == "table"
    and info.filewinid
    and info.filewinid ~= 0
  then
    return info.filewinid
  end
  return vim.api.nvim_get_current_win()
end

local function remember_loclist_origin()
  local win = vim.api.nvim_get_current_win()
  if is_loclist_window(win) then
    return
  end

  review_loclist_origin = {
    win = win,
    view = vim.fn.winsaveview(),
  }
end

local function restore_loclist_origin()
  local origin = review_loclist_origin
  review_loclist_origin = nil

  if not origin or not vim.api.nvim_win_is_valid(origin.win) then
    return
  end

  vim.api.nvim_set_current_win(origin.win)
  pcall(vim.fn.winrestview, origin.view)
end

local function watch_review_loclist_close(win)
  if review_loclist_close_autocmd then
    pcall(vim.api.nvim_del_autocmd, review_loclist_close_autocmd)
  end

  review_loclist_close_autocmd = vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      review_loclist_close_autocmd = nil
      vim.schedule(restore_loclist_origin)
    end,
  })
end

local function close_review_loclist()
  local win = vim.api.nvim_get_current_win()
  local closing_from_loclist = is_loclist_window(win)
  local view = not closing_from_loclist and vim.fn.winsaveview() or nil

  pcall(vim.cmd, "lclose")

  if closing_from_loclist then
    restore_loclist_origin()
    return
  end

  review_loclist_origin = nil
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    pcall(vim.fn.winrestview, view)
  end
end

local function review_loclist_items()
  local items = {}
  for _, comment in ipairs(review_comments) do
    table.insert(items, loclist_item_for_comment(comment))
  end
  return items
end

local function focus_loclist_window()
  local win = loclist_window()
  if not win then
    return nil
  end

  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_set_current_win(win)
  return buf
end

local function open_review_loclist()
  remember_loclist_origin()

  local items = review_loclist_items()

  local loclist_win, loclist_info = loclist_window()
  local owner = loclist_info
      and loclist_info.filewinid
      and loclist_info.filewinid ~= 0
      and loclist_info.filewinid
    or loclist_owner_window()
  vim.fn.setloclist(owner, {}, "r", {
    title = review_loclist_title,
    items = items,
  })

  if loclist_win and vim.api.nvim_win_is_valid(loclist_win) then
    vim.api.nvim_set_current_win(loclist_win)
  else
    if vim.api.nvim_win_is_valid(owner) then
      vim.api.nvim_set_current_win(owner)
    end
    vim.cmd("botright lopen")
    local height =
      math.min(math.max(#items + 4, 8), math.floor(vim.o.lines * 0.4), 33)
    pcall(vim.cmd, ("resize %d"):format(height))
  end

  local buf = focus_loclist_window()
  if not buf then
    return
  end

  watch_review_loclist_close(vim.api.nvim_get_current_win())

  vim.keymap.set("n", "<cr>", function()
    M.edit_comment_at_cursor()
  end, {
    buffer = buf,
    desc = "Edit Pi review comment",
  })
  vim.keymap.set("n", "d", function()
    M.clear_comment_at_cursor()
  end, {
    buffer = buf,
    desc = "Clear Pi review comment",
  })
  vim.keymap.set("x", "d", function()
    M.clear_comments_in_selection()
  end, {
    buffer = buf,
    desc = "Clear selected Pi review comments",
  })
  vim.keymap.set("n", "r", function()
    M.list_comments()
  end, {
    buffer = buf,
    desc = "Refresh Pi review comments",
  })
  vim.keymap.set("n", "q", close_review_loclist, {
    buffer = buf,
    desc = "Close Pi review comments",
  })
end

local function close_review_overlay()
  if vim.env.PI_REVIEW_OVERLAY ~= "1" then
    return
  end

  vim.schedule(function()
    pcall(vim.cmd, "silent! DiffviewClose")
    local ok, err = pcall(vim.cmd, "qa")
    if not ok then
      notify(
        "Review submitted; close Neovim manually: " .. tostring(err),
        vim.log.levels.WARN
      )
    end
  end)
end

function M.add_comment(opts)
  opts = opts or {}
  local context = review_file_context()
  if not context then
    return
  end

  local line1 = opts.line1 or vim.fn.line(".")
  local line2 = opts.line2 or line1
  if line2 < line1 then
    line1, line2 = line2, line1
  end

  local location = line1 == line2 and ("%s:%d"):format(context.file, line1)
    or ("%s:%d-%d"):format(context.file, line1, line2)
  local code = selected_lines(line1, line2)

  Input.textarea({
    prompt = ("Review Comment: %s"):format(location),
    width = review_comment_input_width,
    height = review_comment_input_height,
    filetype = "markdown",
    submit_on_enter = true,
  }, function(msg)
    if not msg or vim.trim(msg) == "" then
      return
    end

    add_review_comment({
      scope = "lines",
      file = context.file,
      location = location,
      line1 = line1,
      line2 = line2,
      filetype = context.filetype,
      code = code,
      comment = msg,
    })
  end)
end

function M.add_file_comment()
  local context = review_file_context()
  if not context then
    return
  end

  Input.textarea({
    prompt = ("Review File Comment: %s"):format(context.file),
    width = review_comment_input_width,
    height = review_comment_input_height,
    filetype = "markdown",
    submit_on_enter = true,
  }, function(msg)
    if not msg or vim.trim(msg) == "" then
      return
    end

    add_review_comment({
      scope = "file",
      file = context.file,
      location = context.file,
      filetype = context.filetype,
      comment = msg,
    })
  end)
end

function M.submit_comments()
  local count = #review_comments
  if count == 0 then
    notify("No pending review comments", vim.log.levels.INFO)
    return
  end

  if send_to_pi(pending_payload()) then
    review_comments = {}
    reset_review_comment_ids()
    notify(
      ("Wrote %d review %s to Pi input"):format(count, plural(count, "comment"))
    )
    close_review_loclist()
    close_review_overlay()
  end
end

function M.list_comments()
  if #review_comments == 0 then
    close_review_loclist()
    notify("No pending review comments", vim.log.levels.INFO)
    return
  end

  open_review_loclist()
end

function M.edit_comment(id)
  local comment = find_comment_by_id(id)
  if not comment then
    notify(("No review comment #%d"):format(id), vim.log.levels.WARN)
    return
  end

  Input.textarea({
    prompt = ("Edit %s"):format(comment_label(comment)),
    default = comment.comment,
    width = review_comment_input_width,
    height = review_comment_input_height,
    filetype = "markdown",
    submit_on_enter = true,
  }, function(msg)
    if not msg then
      return
    end

    if vim.trim(msg) == "" then
      notify("Empty review comment was not saved", vim.log.levels.WARN)
      return
    end

    comment.comment = msg
    notify(("Updated review comment #%d"):format(comment.id))
  end)
end

function M.edit_comment_at_cursor()
  local id = current_loclist_comment_id()
  if not id then
    notify("No review comment under cursor", vim.log.levels.WARN)
    return
  end

  M.edit_comment(id)
end

function M.clear_comment_at_cursor()
  local id = current_loclist_comment_id()
  if not id then
    notify("No review comment under cursor", vim.log.levels.WARN)
    return
  end

  local removed = clear_comment_by_id(id)
  if not removed then
    notify(("No review comment #%d"):format(id), vim.log.levels.WARN)
    return
  end

  notify(("Cleared review comment #%d"):format(removed.id))
  M.list_comments()
end

function M.clear_comments_in_selection()
  local ids = loclist_comment_ids_in_range(vim.fn.line("'<"), vim.fn.line("'>"))
  if #ids == 0 then
    notify("No review comments selected", vim.log.levels.WARN)
    return
  end

  local removed = clear_comment_ids(ids)
  notify(("Cleared %d review %s"):format(removed, plural(removed, "comment")))
  M.list_comments()
end

function M.toggle_comments()
  if loclist_window() then
    close_review_loclist()
    return
  end

  M.list_comments()
end

local function setup_review_keymaps()
  vim.keymap.set("n", "<leader>c", "<cmd>PiReviewComment<cr>", {
    desc = "Add Pi line review comment",
  })
  vim.keymap.set("x", "<leader>c", ":<C-U>'<,'>PiReviewComment<cr>", {
    desc = "Add Pi range review comment",
  })
  vim.keymap.set("n", "<leader>C", "<cmd>PiReviewFileComment<cr>", {
    desc = "Add Pi file review comment",
  })
  vim.keymap.set("n", "<leader>l", function()
    M.toggle_comments()
  end, {
    desc = "Toggle Pi review comments",
  })
end

function M.setup()
  if not is_review_session() then
    return
  end

  setup_review_keymaps()

  vim.api.nvim_create_user_command("PiReviewComment", function(opts)
    M.add_comment(opts)
  end, {
    desc = "Add a line or range review comment to the pending Pi review",
    range = true,
  })

  vim.api.nvim_create_user_command("PiReviewFileComment", function()
    M.add_file_comment()
  end, {
    desc = "Add a whole-file review comment to the pending Pi review",
  })

  vim.api.nvim_create_user_command("PiReviewList", function()
    M.list_comments()
  end, {
    desc = "List pending Pi review comments",
  })

  vim.api.nvim_create_user_command("PiSubmitReview", function()
    M.submit_comments()
  end, {
    desc = "Write pending Pi review comments into the Pi input",
  })
end

return M
