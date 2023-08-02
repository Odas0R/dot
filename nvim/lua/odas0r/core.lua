local Utils = require("odas0r.utils")

-----------------------------------------
-- Hot Module Reloading
-----------------------------------------

-- Development (Plugins)
Utils.cmd("Reload", function(opts)
  local name = opts.fargs[1]

  -- call the helper method to reload the module
  -- and give some feedback
  R(name)
  P(name .. " RELOADED!!!")
end, {
  nargs = 1,
})

Utils.autocmd("BufWritePost", {
  group = Utils.augroup("reload_config"),
  pattern = "*.lua",
  callback = function()
    local bufname = vim.api.nvim_buf_get_name(0)
    local directories = {}

    for dir in vim.fs.parents(bufname) do
      if vim.fs.basename(dir) == "dot" then
        return
      end

      -- if dir contains /odas0r then we found the root directory
      if vim.fs.basename(dir) == "odas0r" then
        directories[#directories + 1] = vim.fs.basename(dir)
        break
      else
        directories[#directories + 1] = vim.fs.basename(dir)
      end
    end

    -- if there's no "odas0r" on directories, return
    if not vim.tbl_contains(directories, "odas0r") then
      return
    end

    if #directories == 1 and directories[1] == "odas0r" then
      local name = "odas0r" .. "." .. vim.fs.basename(bufname):gsub(".lua", "")
      R(name)
      -- P(name .. " RELOADED!!!")
    end

    if #directories > 1 then
      local name = table.concat(Utils.reverse(directories), ".") .. "." .. vim.fs.basename(bufname):gsub(".lua", "")
      R(name)
      -- P(name .. " RELOADED!!!")
    end
  end,
})
