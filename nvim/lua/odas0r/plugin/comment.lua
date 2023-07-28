local M = {}

M.init = function() end

M.config = function()
  -- Url for configuration options
  -- https://github.com/numToStr/Comment.nvim#configuration-optional
  require("Comment").setup({
    pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
  })
end

return M
