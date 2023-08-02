local Utils = require("odas0r.utils")
local Job = require("plenary.job")

local zet = {}

zet.query = function(query)
  if terminal ~= nil then
    terminal:close()
  end
  require("telescope.builtin").live_grep(require("telescope.themes").get_dropdown({
    prompt_title = "Zet Query",
    cwd = "$HOME/github.com/odas0r/zet",
    search_dirs = {
      "fleet",
      "permanent",
    },
    default_text = query or "",
  }))
end

zet.create = function(title)
  local path = nil
  Job
    :new({
      command = "zet",
      args = { "new", "--raw", title },
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
end

vim.cmd([[highlight FloatBorder guifg=GruvboxFg1]])
vim.cmd([[highlight FloatTitle guifg=GruvboxFg1]])

--------------------------------
-- Commands
--------------------------------

Utils.cmd("ZetQuery", function(opts)
  local query = opts.fargs[1] or ""
  zet.query(query)
end, {
  nargs = "?",
  desc = "Query zet files",
})
Utils.cmd("ZetNew", function(opts)
  local title = opts.fargs[1] or ""
  if title == "" then
    Input({
      callback = function(input)
        zet.create(input)
      end,
    })
  else
    zet.create(title)
  end
end, {
  nargs = "?",
  desc = "Create a new zet file",
})

--------------------------------
-- Keymaps
-------------------------------

Utils.map("n", "<leader>zf", "<cmd>ZetQuery<CR>", { silent = true })
Utils.map("n", "<leader>zn", "<cmd>ZetNew<CR>", { silent = true })

--------------------------------
-- UI
--------------------------------

function Input(opts)
  local original_list_option = vim.o.list
  vim.o.list = false

  -- create new empty buffer for our window
  local buf = vim.api.nvim_create_buf(false, true)

  -- get the editor's maximum width and height
  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")

  -- calculate our floating window size
  local win_width = math.ceil(width * 0.25) -- Less width
  local win_height = 1 -- More height

  -- and its starting position
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  -- set some options for our new buffer
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "prompt")

  -- create a new floating window, centered in the editor
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = win_width,
    height = win_height,
    border = "rounded",
    style = "minimal",
    title = " New Zettel ",
    title_pos = "center",
    noautocmd = true,
  })

  -- hide the line numbers
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:FloatBorder") -- Set the background to transparent
  vim.cmd(string.format("autocmd WinLeave <buffer=%s> :lua vim.api.nvim_win_close(%s, true)", buf, win))

  -- set prompt and make it "centered" by adding leading spaces
  vim.fn.prompt_setprompt(buf, "  ")
  Utils.map("i", "<CR>", function()
    local input = vim.fn.getline("."):sub(3, -1)
    vim.cmd([[q!]])
    opts.callback(input)
  end, { buffer = buf, silent = true })

  Utils.map("i", { "<ESC>", "q", "<C-c>" }, function()
    vim.cmd([[q!]])
  end, { buffer = buf, silent = true })

  vim.cmd([[startinsert!]])
  vim.o.list = original_list_option
end
