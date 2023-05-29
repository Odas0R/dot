local utils = require("odas0r.utils")
local a = require("plenary.async")

-----------------------------------------
-- Mappings
-----------------------------------------

-- General
utils.keymap("n", "<leader>vu", ":so " .. vim.env.HOME .. "/.config/nvim/init.lua<CR>")
utils.keymap("n", "<C-l>", ":nohl<CR>", { silent = true })
utils.keymap("n", "<leader>s", ":set spell!<CR>", { silent = true })
utils.keymap("n", "<leader>p", ":set paste!<CR>", { silent = true })

-- Quickfix
utils.keymap("n", "<C-j>", ":cnext<CR>", { silent = true })
utils.keymap("n", "<C-k>", ":cprev<CR>", { silent = true })

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
utils.keymap("n", "<C-w>\\", ":vsplit<CR> | :wincmd l<CR>", { silent = true })
utils.keymap("n", "<C-w>-", ":split<CR> | :wincmd b<CR>", { silent = true })
utils.keymap("n", "<C-w>H", ":vertical resize -5<CR>", { silent = true })
utils.keymap("n", "<C-w>J", ":resize +5<CR>", { silent = true })
utils.keymap("n", "<C-w>K", ":resize -5<CR>", { silent = true })
utils.keymap("n", "<C-w>L", ":vertical resize +5<CR>", { silent = true })

-- Development (Plugins)
utils.cmd("Reload", function(opts)
  local name = opts.fargs[1]

  -- call the helper method to reload the module
  -- and give some feedback
  R(name)
  -- P(name .. " RELOADED!!!")
end, {
  nargs = 1,
})

-----------------------------------------
-- Autocommands
-----------------------------------------
local group = vim.api.nvim_create_augroup("ReloadConfig", {
  clear = true,
})

utils.autocmd("BufWritePost", {
  group = group,
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
      local module = "odas0r" .. "." .. vim.fs.basename(bufname):gsub(".lua", "")
      vim.cmd("Reload " .. module)
    end

    if #directories > 1 then
      local module = table.concat(utils.reverse(directories), ".")
      vim.cmd("Reload " .. module)
    end
  end,
})

-- dont list quickfix buffers
utils.autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})

utils.autocmd("BufRead", {
  pattern = "*.env*",
  callback = function()
    vim.opt_local.filetype = "config"
  end,
})

-- return to last edit position when opening
utils.autocmd("BufReadPost", {
  pattern = "*",
  callback = function()
    if vim.fn.line("'\"") > 0 and vim.fn.line("'\"") <= vim.fn.line("$") then
      vim.cmd('normal! g`"')
    end
  end,
})

utils.autocmd({ "BufEnter" }, {
  pattern = { "*.md", "*.txt" },
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.spell = true
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.tw = 79
    vim.opt_local.foldlevel = 99
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

utils.autocmd({ "BufEnter" }, {
  pattern = { "*" },
  callback = function()
    local buf_path = vim.fn.expand("%:p")
    local filename = "/home/odas0r/.nvim-buf" -- replace this with your file's path

    a.run(function()
      local err, fd = a.uv.fs_open(filename, "w", 438)
      assert(not err, err)
      err = a.uv.fs_write(fd, buf_path, -1)
      assert(not err, err)
      err = a.uv.fs_close(fd)
      assert(not err, err)
    end)
  end,
})
