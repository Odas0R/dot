local utils = require("odas0r.utils")
local Job = require("plenary.job")

utils.cmd("ZetQuery", function(opts)
  local query = opts.fargs[1] or ""

  require("telescope.builtin").live_grep({
    prompt_title = "Zet Query",
    cwd = "$HOME/github.com/odas0r/zet",
    search_dirs = {
      "fleet",
      "permanent",
    },
    default_text = query,
  })
end, {
  nargs = "?",
  desc = "Query zet files",
})

utils.cmd("ZetNew", function(opts)
  local title = opts.fargs[1]
  local path = nil

  Job
    :new({
      command = "zet",
      args = { "new", title },
      cwd = "/home/odas0r/github.com/odas0r/zet-cmd",
      on_exit = function(j, code)
        if code == 0 then
          path = j:result()[1]
          print("Created: " .. path)
        else
          -- show Error message on red
          print("Error: " .. j:stderr_result()[1])
        end
      end,
    })
    :sync()

  if path then
    vim.cmd("e " .. path)
  end
end, {
  nargs = 1,
  desc = "Create a new zet file",
})
