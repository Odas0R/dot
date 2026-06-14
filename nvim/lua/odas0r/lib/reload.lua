local require = require

local ok, plenary_reload = pcall(require, "plenary.reload")
local reloader = ok and plenary_reload.reload_module or require

P = function(v)
  print(vim.inspect(v))
  return v
end

RELOAD = function(...)
  local reload_ok, reload = pcall(require, "plenary.reload")
  if reload_ok then
    reloader = reload.reload_module
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

return {
  reload = RELOAD,
  require = R,
  lazy_reload = LR,
  inspect = P,
}
