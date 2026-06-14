local autocmd = require("odas0r.lib.autocmd")
local a = require("plenary.async")

-- @Source: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Check if we need to reload the file when it changed
autocmd.create({ "FocusGained", "TermClose", "TermLeave" }, {
  group = autocmd.group("checktime"),
  command = "checktime",
  desc = "Reload file on external changes",
})

-- Highlight on yank
autocmd.create("TextYankPost", {
  group = autocmd.group("highlight_yank"),
  desc = "Highlight selection on yank",
  callback = function()
    vim.hl.hl_op()
  end,
})

-- resize splits if window got resized
autocmd.create({ "VimResized" }, {
  group = autocmd.group("resize_splits"),
  desc = "Resize splits equally on window resize",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Note: sessions make this unnecessary
--
-- go to last loc when opening a buffer
-- autocmd.create("BufReadPost", {
--   group = autocmd.group("last_loc"),
--   desc = "Jump to last known cursor position on opening a buffer",
--   callback = function()
--     local exclude = { "gitcommit" }
--     local buf = vim.api.nvim_get_current_buf()
--     if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
--       return
--     end
--     local mark = vim.api.nvim_buf_get_mark(buf, '"')
--     local lcount = vim.api.nvim_buf_line_count(buf)
--     -- Check mark is valid and within buffer bounds
--     if mark[1] > 0 and mark[1] <= lcount then
--       pcall(vim.api.nvim_win_set_cursor, 0, mark)
--     end
--   end,
-- })

-- close some filetypes with <q>
autocmd.create("FileType", {
  group = autocmd.group("close_with_q"),
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
  },
  desc = "Map 'q' to close specific filetypes and remove from buffer list",
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set(
      "n",
      "q",
      "<cmd>close<cr>",
      { buffer = event.buf, silent = true }
    )
  end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
autocmd.create({ "BufWritePre" }, {
  group = autocmd.group("auto_create_dir"),
  desc = "Automatically create parent directories if they don't exist on save",
  callback = function(event)
    -- Skip remote files (e.g., scp://)
    if event.match:match("^%w%w+://") then
      return
    end
    -- Get the full path; resolve symlinks if possible
    local file = vim.loop.fs_realpath(event.match) or event.match
    -- Get the directory part of the path
    local dir = vim.fn.fnamemodify(file, ":p:h")
    -- Create the directory recursively if it doesn't exist
    vim.fn.mkdir(dir, "p")
  end,
})

-- HotReload for Flutter
autocmd.create("BufWritePost", {
  pattern = "*.dart",
  group = autocmd.group("flutter_hot_reload"),
  desc = "Trigger Flutter hot reload on saving a Dart file",
  callback = function()
    vim.cmd("silent !flutter-hot-reload")
  end,
})

-- Set .env as config files (shell script syntax)
autocmd.create("BufRead", {
  pattern = { "*.env*", "*.vars" },
  group = autocmd.group("env_filetype"),
  desc = "Set filetype to 'sh' for .env and .vars files",
  callback = function()
    vim.opt_local.filetype = "sh"
  end,
})

-- Better writing defaults for Markdown and text files
autocmd.create({ "BufEnter" }, {
  pattern = { "*.md", "*.txt" },
  group = autocmd.group("write_options"),
  desc = "Set buffer-local options for writing (spellcheck, textwidth, etc.)",
  callback = function()
    local opt = vim.opt_local
    opt.spell = true -- Enable spell checking
    opt.number = true -- Enable line numbers
    opt.relativenumber = false -- Disable relative line numbers
    opt.foldlevel = 99 -- Keep folds open by default in these files
    opt.wrap = true -- Consider enabling wrap if needed
    -- Example custom highlight (ensure color #FFD700 is defined or use a standard name)
    vim.api.nvim_set_hl(0, "markdownBold", { fg = "#FFD700", bold = true })
  end,
})

-- Write the current buffer file path to ~/.nvim-buf -- Useful for commands
-- that require buffer info.
autocmd.create({ "BufEnter", "FocusGained" }, {
  pattern = { "*" },
  group = autocmd.group("write_current_path"),
  desc = "Write current buffer path to ~/.nvim-buf",
  callback = function()
    local buf_path = vim.fn.expand("%:p")
    if buf_path == "" then
      return
    end -- Don't write if path is empty
    local filename = os.getenv("HOME") .. "/.nvim-buf" -- replace this with your file's path

    -- Use Plenary async library
    a.run(function()
      local err, fd = a.uv.fs_open(filename, "w", 438) -- 438 is 0666 in octal
      if err then
        vim.notify(
          "Error opening " .. filename .. ": " .. err,
          vim.log.levels.ERROR
        )
        return
      end
      local write_err = a.uv.fs_write(fd, buf_path, -1)
      if write_err then
        vim.notify(
          "Error writing to " .. filename .. ": " .. write_err,
          vim.log.levels.ERROR
        )
        -- Still try to close the file descriptor
      end
      local close_err = a.uv.fs_close(fd)
      if close_err then
        vim.notify(
          "Error closing " .. filename .. ": " .. close_err,
          vim.log.levels.ERROR
        )
      end
    end)
  end,
})

-- on vim close delete the content of ~/.nvim-buf
-- autocmd.create({ "VimLeave" }, {
--   group = autocmd.group("delete_current_path"),
--   callback = function()
--     local filename = os.getenv("HOME") .. "/.nvim-buf" -- replace this with your file's path
--     a.run(function()
--       local err, fd = a.uv.fs_open(filename, "w", 438)
--       assert(not err, err)
--       err = a.uv.fs_close(fd)
--       assert(not err, err)
--     end)
--   end,
-- })
--
-- when tsconfig.json use json filetype instead of jsonc (jsonc is not supported by lsp)
-- autocmd.create("BufRead", {
--   pattern = { "tsconfig.json" },
--   group = autocmd.group("tsconfig_jsonc"),
--   callback = function()
--     vim.opt_local.filetype = "json"
--   end,
-- })
