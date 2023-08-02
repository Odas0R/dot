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

local function augroup(name)
  return vim.api.nvim_create_augroup("config_" .. name, { clear = true })
end

local map = custom_nvim_keymap
local autocmd = vim.api.nvim_create_autocmd
local cmd = vim.api.nvim_create_user_command

local M = {}

M.map = map
M.autocmd = autocmd
M.cmd = cmd
M.augroup = augroup

M.reverse = function(t)
  local len = #t + 1
  for i = 1, math.floor(#t / 2) do
    t[i], t[len - i] = t[len - i], t[i]
  end
  return t
end

return M
