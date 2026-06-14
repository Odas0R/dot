local Bridge = require("odas0r.features.pi_review.bridge")
local Git = require("odas0r.lib.git")
local Input = require("odas0r.ui.input")
local Loclist = require("odas0r.lib.loclist")
local Path = require("odas0r.lib.path")
local Store = require("odas0r.features.pi_review.store")
local Text = require("odas0r.lib.text")

local M = {}

local review_comment_input_width = 64
local review_comment_input_height = 7
local review_loclist_title = "Pi review comments"
local comments = Store.new()

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Pi review" })
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
      if value ~= "" and not Path.is_uri(value) then
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
  if name ~= "" and not Path.is_uri(name) then
    return name
  end
  return path_from_diffview_vars() or name
end

local function selected_lines(line1, line2)
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  return table.concat(lines, "\n")
end

local function review_root()
  local file = current_file()
  local root_start = file
      and not Path.is_uri(file)
      and vim.fn.fnamemodify(file, ":p:h")
    or vim.fn.getcwd()
  return Git.root(root_start)
end

local function review_file_context()
  local file = current_file()
  local root = review_root()
  if not root then
    notify("Not inside a Git repository", vim.log.levels.ERROR)
    return nil
  end

  return {
    file = Path.relative_to(root, file) or "<unknown>",
    filetype = vim.bo.filetype,
  }
end

local function textarea(opts, on_confirm)
  Input.textarea(
    vim.tbl_extend("force", {
      width = review_comment_input_width,
      height = review_comment_input_height,
      filetype = "markdown",
      submit_on_enter = true,
    }, opts or {}),
    on_confirm
  )
end

local function add_review_comment(comment)
  comments:add(comment)
  notify(
    ("Added review comment #%d (%d pending)"):format(
      comment.id,
      comments:count()
    )
  )
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

local function loclist_item_for_comment(comment)
  local item = {
    lnum = comment.line1 or 1,
    col = 1,
    text = ("#%d [%s] — %s"):format(
      comment.id,
      comment_kind(comment),
      Text.truncate(comment_summary(comment), 80)
    ),
  }

  if comment.file and comment.file ~= "" and comment.file ~= "<unknown>" then
    item.filename = comment.file
  end

  return item
end

local function review_loclist_items()
  local items = {}
  for _, comment in ipairs(comments:all()) do
    table.insert(items, loclist_item_for_comment(comment))
  end
  return items
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

local function close_review_loclist()
  Loclist.close(review_loclist_title)
end

local function set_review_loclist_keymaps(buf)
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

local function open_review_loclist()
  local items = review_loclist_items()
  local buf = Loclist.open({
    title = review_loclist_title,
    items = items,
    height = function(count)
      return math.min(math.max(count + 4, 8), math.floor(vim.o.lines * 0.4), 33)
    end,
  })

  if buf then
    set_review_loclist_keymaps(buf)
  end
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

  textarea({
    prompt = ("Review Comment: %s"):format(location),
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

  textarea({
    prompt = ("Review File Comment: %s"):format(context.file),
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
  local count = comments:count()
  if count == 0 then
    notify("No pending review comments", vim.log.levels.INFO)
    return
  end

  if Bridge.send(comments:payload(), notify) then
    comments:clear_all()
    notify(
      ("Wrote %d review %s to Pi input"):format(
        count,
        Text.plural(count, "comment")
      )
    )
    close_review_loclist()
    close_review_overlay()
  end
end

function M.list_comments()
  if comments:count() == 0 then
    close_review_loclist()
    notify("No pending review comments", vim.log.levels.INFO)
    return
  end

  open_review_loclist()
end

function M.edit_comment(id)
  local comment = comments:find(id)
  if not comment then
    notify(("No review comment #%d"):format(id), vim.log.levels.WARN)
    return
  end

  textarea({
    prompt = ("Edit %s"):format(comment_label(comment)),
    default = comment.comment,
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

  local removed = comments:clear(id)
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

  local removed = comments:clear_many(ids)
  notify(
    ("Cleared %d review %s"):format(removed, Text.plural(removed, "comment"))
  )
  M.list_comments()
end

function M.toggle_comments()
  if Loclist.is_open(review_loclist_title) then
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
  if not Bridge.is_session() then
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
