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
-- @param mode table<string> | string
-- @param lhs string
-- @param rhs string
-- @param opts table
--
-- @usage map("n", "<C-k>", ":cprev<CR>")
-- @usage map({"n", "x"}, "<C-k>", ":cprev<CR>")
--
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

-- @Example
--
-- group = Utils.augroup("terminal"),
local function augroup(name)
  return vim.api.nvim_create_augroup("config_" .. name, { clear = true })
end

local map = custom_nvim_keymap

-- @Example
--
-- Utils.autocmd("TermOpen", {
--   pattern = "*",
--   group = Utils.augroup("terminal"),
--   callback = function()
--     vim.opt_local.number = false
--     vim.opt_local.relativenumber = false
--     vim.opt_local.cursorline = false
--   end,
-- })
--
local autocmd = vim.api.nvim_create_autocmd

local cmd = vim.api.nvim_create_user_command

local M = {}

M.map = map
M.autocmd = autocmd
M.cmd = cmd
M.augroup = augroup
M.slugify = slugify
M.reverse = reverse

return M