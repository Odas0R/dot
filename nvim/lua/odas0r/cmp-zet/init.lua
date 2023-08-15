-- ":h cmp-develop"
-- Very nice source: <https://github.com/f3fora/cmp-spell/blob/20f3347e5834bea04892cffa6259a51ddfb9c61f/lua/cmp-spell/init.lua>

local source = {}
local opts = {}

function source:new()
  local self = setmetatable({}, { __index = source })
  return self
end

---Return whether this source is available in the current context or not (optional).
---@return boolean
function source:is_available()
  return true
end

function source:get_debug_name()
  return "Zet"
end

---Return the keyword pattern for triggering completion (optional).
---If this is ommited, nvim-cmp will use a default keyword pattern. See |cmp-config.completion.keyword_pattern|.
---@return string
function source.get_trigger_characters()
  return { "#", "^" }
end

-- function source:get_keyword_pattern()
--   return [[\K\+]]
-- end

local notes = {
  { id = "c2c6d454-eea4-4b6f-9fed-b06310088b63", title = "Golang is an awesome lang" },
  { id = "fb1a6da6-f00c-49af-8fe1-8825448f1acd", title = "Monorepos are so bloated wtf" },
}

-- Invoke completion (required).
function source:complete(params, callback)
  local line = params.context.cursor_before_line
  local match_start, match_end, content = line:find("%[%[#%s*(.+)")

  if match_start then
    -- NOTE: based on the content, we can return different completions here
    -- NOTE: The way you're going to show the grep results must be done via documentation
    -- window. Like you show only a few lines of the grep results and then you can show more
    -- lines if the user wants to see more.

    local cursor_start = match_start + 2
    local cursor_end = match_end

    local completions = {}

    for _, note in ipairs(notes) do
      local completion = {
        label = note.title,
        filterText = note.title,
        textEdit = {
          range = {
            start = { line = params.context.cursor.line, character = cursor_start },
            ["end"] = { line = params.context.cursor.line, character = cursor_end },
          },
          newText = note.id,
        },
      }
      completions[#completions + 1] = completion
    end

    callback({
      items = completions,
      isIncomplete = true,
    })
  else
    callback({
      items = {},
      isIncomplete = false,
    })
  end
end

---Resolve completion item (optional). This is called right before the completion is about to be displayed.
---Useful for setting the text shown in the documentation window (`completion_item.documentation`).
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
  callback(completion_item)
end

---Executed after the item was selected.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback)
  callback(completion_item)
end

return {
  setup = function(_opts)
    if _opts then
      opts = vim.tbl_deep_extend("force", opts, _opts) -- will extend the default options
    end

    -- register the source
    require("cmp").register_source("zet", source)
  end,
}
