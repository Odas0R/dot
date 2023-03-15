local replace = require("odas0r.replace")

vim.api.nvim_create_user_command("Replace", function(opts)
  replace.replace(opts.fargs[1])
end, {
  nargs = 1,
  desc = "Replace a pattern with another pattern",
  complete = function(arg_lead, cmd_line, cursor_pos)
     return replace.autocomplete(arg_lead, cmd_line, cursor_pos)
  end,
})
