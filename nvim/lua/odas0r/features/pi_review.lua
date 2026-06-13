local Input = require("odas0r.ui.input")

local M = {}

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

function M.open_review()
  local root = review_root()
  if not root then
    notify("Not inside a Git repository", vim.log.levels.ERROR)
    return
  end

  local review_dir = root .. "/.pi"
  vim.fn.mkdir(review_dir, "p")
  vim.cmd.edit(vim.fn.fnameescape(review_dir .. "/review.md"))
end

function M.add_comment(opts)
  opts = opts or {}
  local file = current_file()
  local root = review_root()
  if not root then
    notify("Not inside a Git repository", vim.log.levels.ERROR)
    return
  end

  local line1 = opts.line1 or vim.fn.line(".")
  local line2 = opts.line2 or line1
  if line2 < line1 then
    line1, line2 = line2, line1
  end

  local rel = relative_file(root, file) or "<unknown>"
  local location = line1 == line2 and ("%s:%d"):format(rel, line1)
    or ("%s:%d-%d"):format(rel, line1, line2)
  local code = selected_lines(line1, line2):gsub("```", "`\226\128\139``")

  Input.input(
    { prompt = ("Review comment for %s: "):format(location) },
    function(msg)
      if not msg or msg == "" then
        return
      end

      local review_dir = root .. "/.pi"
      local review_path = review_dir .. "/review.md"
      vim.fn.mkdir(review_dir, "p")

      local f = io.open(review_path, "a")
      if not f then
        notify("Could not open " .. review_path, vim.log.levels.ERROR)
        return
      end

      f:write(("\n- [ ] `%s`\n"):format(location))
      if code ~= "" then
        f:write("  Code:\n\n")
        f:write("  ```" .. vim.bo.filetype .. "\n")
        for line in (code .. "\n"):gmatch("(.-)\n") do
          f:write("  " .. line .. "\n")
        end
        f:write("  ```\n")
      end
      f:write(("  Comment: %s\n"):format(msg))
      f:close()

      notify("Added comment to " .. review_path)
    end
  )
end

function M.setup()
  vim.api.nvim_create_user_command("PiReviewOpen", function()
    M.open_review()
  end, {
    desc = "Open .pi/review.md",
  })

  vim.api.nvim_create_user_command("PiReviewComment", function(opts)
    M.add_comment(opts)
  end, {
    desc = "Append a review comment to .pi/review.md",
    range = true,
  })

  vim.keymap.set("n", "<leader>po", "<cmd>PiReviewOpen<cr>", {
    desc = "Open Pi review file",
  })
end

return M
