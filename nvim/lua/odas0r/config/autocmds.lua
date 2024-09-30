local Utils = require("odas0r.utils")
local a = require("plenary.async")

-- @Source: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Check if we need to reload the file when it changed
Utils.autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = Utils.augroup("checktime"),
  command = "checktime",
})

-- Highlight on yank
Utils.autocmd("TextYankPost", {
  group = Utils.augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- resize splits if window got resized
Utils.autocmd({ "VimResized" }, {
  group = Utils.augroup("resize_splits"),
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- go to last loc when opening a buffer
Utils.autocmd("BufReadPost", {
  group = Utils.augroup("last_loc"),
  callback = function()
    local exclude = { "gitcommit" }
    local buf = vim.api.nvim_get_current_buf()
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- close some filetypes with <q>
Utils.autocmd("FileType", {
  group = Utils.augroup("close_with_q"),
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
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
Utils.autocmd({ "BufWritePre" }, {
  group = Utils.augroup("auto_create_dir"),
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- HotReload for Flutter
Utils.autocmd("BufWritePost", {
  pattern = "*.dart",
  group = Utils.augroup("flutter_hot_reload"),
  callback = function()
    vim.cmd("silent !flutter-hot-reload")
  end,
})

-- Set .env as config files
Utils.autocmd("BufRead", {
  pattern = { "*.env*", "*.vars" },
  group = Utils.augroup("env_filetype"),
  callback = function()
    vim.opt_local.filetype = "sh"
  end,
})

-- Better writing defaults
Utils.autocmd({ "BufEnter" }, {
  pattern = { "*.md", "*.txt" },
  group = Utils.augroup("write_options"),
  callback = function()
    local opt = vim.opt_local
    opt.spell = true
    opt.number = false
    opt.relativenumber = false
    opt.foldlevel = 99

    opt.tw = 79
    -- opt.wrap = true
    -- opt.linebreak = true
    opt.conceallevel = 2

     vim.api.nvim_set_hl(0, "markdownBold", { fg = "#FFD700", bold = true })
  end,
})

-- Write the current buffer file path to ~/.nvim-buf -- Useful for commands
-- that require buffer info.
Utils.autocmd({ "BufEnter", "FocusGained" }, {
  pattern = { "*" },
  group = Utils.augroup("write_current_path"),
  callback = function()
    local buf_path = vim.fn.expand("%:p")
    local filename = os.getenv("HOME") .. "/.nvim-buf" -- replace this with your file's path

    a.run(function()
      local err, fd = a.uv.fs_open(filename, "w", 438)
      assert(not err, err)
      err = a.uv.fs_write(fd, buf_path, -1)
      assert(not err, err)
      err = a.uv.fs_close(fd)
      assert(not err, err)
    end)
  end,
})

-- on vim close delete the content of ~/.nvim-buf
-- Utils.autocmd({ "VimLeave" }, {
--   group = Utils.augroup("delete_current_path"),
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
-- Utils.autocmd("BufRead", {
--   pattern = { "tsconfig.json" },
--   group = Utils.augroup("tsconfig_jsonc"),
--   callback = function()
--     vim.opt_local.filetype = "json"
--   end,
-- })
