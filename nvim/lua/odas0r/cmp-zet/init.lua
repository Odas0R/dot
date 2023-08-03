local defaults = {}

local source = {}

source.new = function()
  print("Sourcing zet")
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "#" }
end

source.complete = function(self, args, callback)
  -- Get your completions here.
  -- You can get them from a file, a database, an API, etc.
  -- Then, call the callback function with your completions.
  -- #C

  local completions = {
    -- The word that will be inserted
    { word = "Completion 1" },
    { word = "Completion 2" },
    -- Add as many completions as you like
  }

  callback(completions)
end

return source
