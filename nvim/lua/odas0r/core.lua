local Utils = require("odas0r.utils")
-----------------------------------------
-- Hot Module Reloading
-----------------------------------------
Utils.cmd("Reload", function(opts)
  local name = opts.fargs[1]
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

    -- Special handling for snippet files
    if bufname:match("/snippets/") then
      -- Safely reload snippets
      local status, err = pcall(function()
        require("luasnip.loaders.from_lua").load({
          paths = os.getenv("HOME") .. "/.config/nvim/lua/odas0r/snippets",
        })
      end)
      if not status then
        vim.notify("Failed to reload snippets: " .. tostring(err), vim.log.levels.ERROR)
      else
        vim.notify("Snippets reloaded successfully", vim.log.levels.INFO)
      end
      return
    end

    -- Regular module reloading logic
    local directories = {}
    for dir in vim.fs.parents(bufname) do
      if vim.fs.basename(dir) == "dot" then
        return
      end
      if vim.fs.basename(dir) == "odas0r" then
        directories[#directories + 1] = vim.fs.basename(dir)
        break
      else
        directories[#directories + 1] = vim.fs.basename(dir)
      end
    end

    if not vim.tbl_contains(directories, "odas0r") then
      return
    end

    local modulePath = table.concat(Utils.reverse(directories), ".")
    local baseFilename = vim.fs.basename(bufname)

    if not baseFilename then
      vim.notify("No filename found", vim.log.levels.ERROR)
      return
    end

    local module
    if baseFilename:match("init.lua") then
      module = modulePath
    else
      module = modulePath .. "." .. baseFilename:gsub("%.lua$", "")
    end

    if module then
      local status, err = pcall(R, module)
      if not status then
        vim.notify("Failed to reload " .. module .. ": " .. tostring(err), vim.log.levels.ERROR)
      else
        vim.notify("Reloading " .. module .. "...", vim.log.levels.INFO)
      end
    end
  end,
})
