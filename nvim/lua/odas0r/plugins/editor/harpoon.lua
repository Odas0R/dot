local autocmd = require("odas0r.lib.autocmd")
local map = require("odas0r.lib.keymap")

local closeTerminal = function()
  if terminal == nil then
    return
  end
  vim.cmd([[
    lua terminal:close()
  ]])
end

return {
  "ThePrimeagen/harpoon",
  init = function()
    -----------------------------------
    -- Keymaps
    -----------------------------------
    map("n", "<leader>a", function()
      require("harpoon.mark").add_file()
    end)
    map("n", "<C-e>", function()
      require("harpoon.ui").toggle_quick_menu()
    end)

    map({ "n", "t" }, "<leader>1", function()
      closeTerminal()
      require("harpoon.ui").nav_file(1)
    end)

    map({ "n", "t" }, "<leader>2", function()
      closeTerminal()
      require("harpoon.ui").nav_file(2)
    end)

    map({ "n", "t" }, "<leader>3", function()
      closeTerminal()
      require("harpoon.ui").nav_file(3)
    end)

    map({ "n", "t" }, "<leader>4", function()
      closeTerminal()
      require("harpoon.ui").nav_file(4)
    end)

    -----------------------------------
    -- Augroups
    -----------------------------------
    autocmd.create("FileType", {
      pattern = "harpoon",
      group = autocmd.group("harpoon"),
      callback = function()
        vim.opt_local.cursorline = true
      end,
    })
  end,
  config = function()
    require("harpoon").setup({
      global_settings = {
        enter_on_sendcmd = true,
      },
    })
  end,
}
