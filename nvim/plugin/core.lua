local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd

-----------------------------------------
-- Mappings
-----------------------------------------

-- General
keymap("n", "<leader>vu", ":so " .. vim.env.HOME .. "/.config/nvim/init.lua<CR>")
keymap("n", "<C-l>", ":nohl<CR>", { silent = true })
keymap("n", "<leader>s", ":set spell!<CR>", { silent = true })
keymap("n", "<leader>p", ":set paste!<CR>", { silent = true })

-- Quickfix
keymap("n", "<C-j>", ":cnext<CR>", { silent = true })
keymap("n", "<C-k>", ":cprev<CR>", { silent = true })

-----------------------------------------
-- Autocommands
-----------------------------------------

-- dont list quickfix buffers
autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})

autocmd("FileType", {
  pattern = "text,markdown",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = true
    vim.opt_local.relativenumber = false
    vim.opt_local.tw = 72
  end,
})

autocmd("BufRead", {
  pattern = "*.env*",
  callback = function()
    vim.opt_local.filetype = "config"
  end,
})

-- return to last edit position when opening
autocmd("BufReadPost", {
  pattern = "*",
  callback = function()
    if vim.fn.line("'\"") > 0 and vim.fn.line("'\"") <= vim.fn.line("$") then
      vim.cmd('normal! g`"')
    end
  end,
})

-- close popup windows with q
autocmd("WinEnter", {
  pattern = "*",
  callback = function()
    local is_popup = vim.api.nvim_win_get_config(0).relative ~= ""

    if is_popup then
      keymap({ "n" }, "q", function()
        -- check if the window is a popup and close it if it is
        local code = vim.api.nvim_replace_termcodes("<C-w>w", true, false, true)
        vim.api.nvim_feedkeys(code, "n", false)
      end, { silent = true })
    else
      -- check if there's q mapping and remove it
      if vim.api.nvim_get_keymap("n")["q"] then
        vim.api.nvim_del_keymap("n", "q")
      end
    end
  end,
})
