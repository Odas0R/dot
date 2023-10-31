-- P and R from https://github.com/tjdevries/config_manager/blob/master/xdg_config/nvim/lua/tj/globals.lua
-- see https://youtu.be/n4Lp4cV8YR0?t=2222
local require = require

local ok, plenary_reload = pcall(require, "plenary.reload")
local reloader = require
if ok then
  reloader = plenary_reload.reload_module
end

P = function(v)
  print(vim.inspect(v))
  return v
end

RELOAD = function(...)
  local ok, plenary_reload = pcall(require, "plenary.reload")
  if ok then
    reloader = plenary_reload.reload_module
  end

  return reloader(...)
end

R = function(name)
  RELOAD(name)
  return require(name)
end

LR = function(name)
  local plugin = require("lazy.core.config").plugins[name]
  return require("lazy.core.loader").reload(plugin)
end

-- ========================================
-- Helper functions
-- ========================================
local function slugify(str)
  str = string.lower(str)
  str = string.gsub(str, " ", "-")
  str = string.gsub(str, "[^a-z0-9-]", "")
  str = string.gsub(str, "-$", "")

  return str
end

local function reverse(t)
  local len = #t + 1
  for i = 1, math.floor(#t / 2) do
    t[i], t[len - i] = t[len - i], t[i]
  end
  return t
end

-- Creates a custom keymap using vim.keymap.set with default options, noremap
-- and silent.
--
-- Usage:
--
-- ```lua
-- map("n", "<C-k>", ":cprev<CR>")
-- map({"n", "x"}, "<C-k>", ":cprev<CR>")
-- ```
local custom_nvim_keymap = function(mode, lhs, rhs, opts)
  -- local options = {}
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  -- if lhs is a table, then we are mapping multiple keys to the same rhs
  -- e.g. { "a", "b", "c" } -> rhs
  if type(lhs) == "table" then
    for _, key in ipairs(lhs) do
      vim.keymap.set(mode, key, rhs, options)
    end
  else
    vim.keymap.set(mode, lhs, rhs, options)
  end
end

-- Create or get an autocommand group |autocmd-groups|.
--
-- ```lua
-- group = Utils.augroup("terminal")
-- ```
local function augroup(name)
  return vim.api.nvim_create_augroup("config_" .. name, { clear = true })
end

local map = custom_nvim_keymap

-- autocmd({event}, {*opts*})                  *nvim_create_autocmd()*
--
-- Creates an |autocommand| event handler, defined by `callback` (Lua function
-- or Vimscript function name string) or `command` (Ex command string).
--
-- ```lua
-- Utils.autocmd("TermOpen", {
--   pattern = "*",
--   group = Utils.augroup("terminal"),
--   callback = function()
--     vim.opt_local.number = false
--     vim.opt_local.relativenumber = false
--     vim.opt_local.cursorline = false
--   end,
-- })
-- ```
--
-- Check `:h nvim_create_autocmd()`
local autocmd = vim.api.nvim_create_autocmd

local cmd = vim.api.nvim_create_user_command

-- vim.ui.input({opts}, {on_confirm})                            *vim.ui.input()*
--
-- Prompts the user for input, allowing arbitrary (potentially asynchronous)
-- work until `on_confirm`.
--
-- Example:
-- ```lua
-- vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
--   vim.o.shiftwidth = tonumber(input)
-- end)
-- ```
--
-- Check :h vim.ui.input
local input = vim.ui.input

local M = {}

M.autocmd = autocmd
M.cmd = cmd
M.input = input

M.map = map
M.augroup = augroup
M.slugify = slugify
M.reverse = reverse

return M
