local Utils = require("odas0r.utils")

local M = {}

M.init = function()
  -----------------------------------
  -- Keymaps
  -----------------------------------
  Utils.map("n", "<leader>a", function()
    require("harpoon.mark").add_file()
  end, { silent = true })
  Utils.map("n", "<C-e>", function()
    require("harpoon.ui").toggle_quick_menu()
  end, { silent = true })

  Utils.map({ "n", "t" }, "<leader>1", function()
    vim.cmd([[
    lua terminal:close()
  ]])
    require("harpoon.ui").nav_file(1)
  end, { silent = true })

  Utils.map({ "n", "t" }, "<leader>2", function()
    vim.cmd([[
    lua terminal:close()
  ]])
    require("harpoon.ui").nav_file(2)
  end, { silent = true })

  Utils.map({ "n", "t" }, "<leader>3", function()
    vim.cmd([[
    lua terminal:close()
  ]])
    require("harpoon.ui").nav_file(3)
  end, { silent = true })

  Utils.map({ "n", "t" }, "<leader>4", function()
    vim.cmd([[
    lua terminal:close()
  ]])
    require("harpoon.ui").nav_file(4)
  end, { silent = true })
  -----------------------------------
  -- Augroups
  -----------------------------------
  Utils.autocmd("FileType", {
    pattern = "harpoon",
    group = Utils.augroup("harpoon"),
    callback = function()
      vim.opt_local.cursorline = true
    end,
  })
end

M.config = function()
  require("harpoon").setup({
    global_settings = {
      enter_on_sendcmd = true,
    },
  })
end

return M
