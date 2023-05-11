-- P and R from https://github.com/tjdevries/config_manager/blob/master/xdg_config/nvim/lua/tj/globals.lua
-- see https://youtu.be/n4Lp4cV8YR0?t=2222
P = function(v)
  print(vim.inspect(v))
  return v
end

local ok, plenary_reload = pcall(require, "plenary.reload")
local reloader = require
if ok then
  reloader = plenary_reload.reload_module
end

RELOAD = function(...)
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

local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd
local cmd = vim.api.nvim_create_user_command

local M = {}

M.keymap = keymap
M.autocmd = autocmd
M.cmd = cmd

M.reverse = function(t)
  local len = #t + 1
  for i = 1, math.floor(#t / 2) do
    t[i], t[len - i] = t[len - i], t[i]
  end
  return t
end

return M
