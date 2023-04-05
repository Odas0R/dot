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

-- [[
--     Window Management
--
--     <C-w>h/j/k/l: move to window
--     <C-w>H/J/K/L: resize window
--     <C-w>\\: split vertically and go to it
--     <C-w>-: split horizontally
--     <C-w>x: exchange window with next
--     <C-w>o: close other windows
--     <C-w>T: move all windows to new tab
-- ]]

-- Window management
keymap("n", "<C-w>\\", ":vsplit<CR> | :wincmd l<CR>", { silent = true })
keymap("n", "<C-w>-", ":split<CR> | :wincmd b<CR>", { silent = true })
keymap("n", "<C-w>H", ":vertical resize -5<CR>", { silent = true })
keymap("n", "<C-w>J", ":resize +5<CR>", { silent = true })
keymap("n", "<C-w>K", ":resize -5<CR>", { silent = true })
keymap("n", "<C-w>L", ":vertical resize +5<CR>", { silent = true })

-- Development (Plugins)
vim.api.nvim_create_user_command("Reload", function(opts)
  local name = opts.fargs[1]

  -- call the helper method to reload the module
  -- and give some feedback
  R(name)
  P(name .. " RELOADED!!!")
end, {
  nargs = 1,
})

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

autocmd({ "BufRead", "BufEnter" }, {
  pattern = "*.astro",
  callback = function()
    vim.opt_local.filetype = "astro"
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


-- vim-markdown settings

-- vim.g.vim_markdown_folding_disabled = 1
-- vim.g.vim_markdown_conceal_code_blocks = 1
-- vim.g.vim_markdown_new_list_item_indent = 2
-- vim.g.vim_markdown_no_extensions_in_markdown = 0
-- vim.g.vim_markdown_autowrite = 1
-- vim.g.vim_markdown_edit_url_in = "current"
-- vim.g.vim_markdown_conceal = 2

autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.tw = 79
    vim.opt_local.foldlevel = 99
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})
