---@class Busted
---@field public describe fun(description: string, callback: fun()):void
---@field public it fun(description: string, callback: fun()):void
---@field public before_each fun(callback: fun()):void
---@field public after_each fun(callback: fun()):void
---@field public teardown fun(callback: fun()):void
---@field public before_all fun(callback: fun()):void
---@field public after_all fun(callback: fun()):void

---@type Busted
local busted = {
  describe = function(description, callback) end,
  it = function(description, callback) end,
  before_each = function(callback) end,
  after_each = function(callback) end,
  teardown = function(callback) end,
  before_all = function(callback) end,
  after_all = function(callback) end,
}

_G.describe = busted.describe
_G.it = busted.it
_G.before_each = busted.before_each
_G.after_each = busted.after_each
_G.teardown = busted.teardown
_G.before_all = busted.before_all
_G.after_all = busted.after_all
