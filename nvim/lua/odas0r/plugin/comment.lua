local Utils = require("odas0r.utils")

local M = {}

M.keys = function()
  return {
    { "gc", mode = "v", desc = "Comment visual" },
    { "gcc", mode = "n", desc = "Comment one line" },
  }
end

M.init = function()
  Utils.autocmd("FileType", {
    pattern = "dart",
    callback = function()
      vim.bo.commentstring = "// %s"
    end,
  })
end

M.config = function()
  -- Url for configuration options
  -- https://github.com/numToStr/Comment.nvim#configuration-optional
  require("Comment").setup({
    pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
  })
end

return M
