local M = {}

M.search = function(cwd)
  require("telescope.builtin").live_grep({
    prompt_title = "[All]",
    cwd = cwd,
    use_regex = true,
    hidden = true,
  })
end

return M
