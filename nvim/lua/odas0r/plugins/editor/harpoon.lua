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

local function applyHarpoonHighlights()
  local floatBorder = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })

  vim.api.nvim_set_hl(0, "HarpoonNormal", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "HarpoonBorder", { fg = floatBorder.fg, bg = "NONE" })
  vim.api.nvim_set_hl(0, "HarpoonCursorLine", { bg = "NONE", underline = true })
end

local function toggleQuickMenu()
  local harpoon = require("harpoon")
  harpoon.ui:toggle_quick_menu(harpoon:list(), {
    ui_width_ratio = 0.45,
    ui_max_width = 70,
    height_in_lines = 8,
  })
end

return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  init = function()
    -----------------------------------
    -- Keymaps
    -----------------------------------
    map("n", "<leader>a", function()
      require("harpoon"):list():add()
    end)
    map("n", "<C-e>", toggleQuickMenu)

    map({ "n", "t" }, "<leader>1", function()
      closeTerminal()
      require("harpoon"):list():select(1)
    end)

    map({ "n", "t" }, "<leader>2", function()
      closeTerminal()
      require("harpoon"):list():select(2)
    end)

    map({ "n", "t" }, "<leader>3", function()
      closeTerminal()
      require("harpoon"):list():select(3)
    end)

    map({ "n", "t" }, "<leader>4", function()
      closeTerminal()
      require("harpoon"):list():select(4)
    end)

    -----------------------------------
    -- Augroups
    -----------------------------------
    local harpoonGroup = autocmd.group("harpoon")

    autocmd.create("ColorScheme", {
      group = harpoonGroup,
      callback = applyHarpoonHighlights,
    })

    autocmd.create("FileType", {
      pattern = "harpoon",
      group = harpoonGroup,
      callback = function()
        vim.opt_local.cursorline = true
        vim.wo.winhighlight = table.concat({
          "Normal:HarpoonNormal",
          "NormalFloat:HarpoonNormal",
          "FloatBorder:HarpoonBorder",
          "CursorLine:HarpoonCursorLine",
        }, ",")
      end,
    })
  end,
  config = function()
    applyHarpoonHighlights()
    require("harpoon"):setup()
  end,
}
