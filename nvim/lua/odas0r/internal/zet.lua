local Utils = require("odas0r.utils")
local Job = require("plenary.job")

local zet = {}

local function exec(cmd, args)
  local result = nil
  Job
    :new({
      command = cmd,
      args = args,
      on_exit = function(j, code)
        if code == 0 then
          result = j:result()[1]
        else
          -- show Error message on red
          print("Error: " .. j:stderr_result()[1])
        end
      end,
    })
    :sync()
  return result
end

zet.grep = function(query)
  if terminal ~= nil then
    terminal:close()
  end
  require("telescope.builtin").live_grep(require("telescope.themes").get_dropdown({
    prompt_title = "Zet Query",
    cwd = "$HOME/github.com/odas0r/zet",
    preview_width = 0.6,
    search_dirs = {
      "fleet",
      "permanent",
    },
    default_text = query or "",
  }))
end

zet.create = function(title)
  local raw_data = exec("zet", { "new", "--raw", title })
  if raw_data == nil then
    return
  end

  local zettel = vim.json.decode(raw_data)
  vim.cmd("e " .. zettel.path)
end

zet.open_last = function()
  local raw_data = exec("zet", { "last" })
  if raw_data == nil then
    return
  end

  local zettel = vim.json.decode(raw_data)
  vim.cmd("e " .. zettel.path)
end

zet.brokenlinks = function()
  local raw_data = exec("zet", { "brokenlinks" })
  if raw_data == nil then
    return
  end

  local data = vim.json.decode(raw_data, { array = true })
  local loclist = {}

  for _, zettel in ipairs(data) do
    table.insert(loclist, {
      filename = zettel.path,
      text = zettel.title,
    })
  end

  vim.fn.setqflist(loclist, "r")
  vim.cmd("copen")
end

zet.backlog = function()
  local raw_data = exec("zet", { "backlog" })
  if raw_data == nil then
    return
  end

  local data = vim.json.decode(raw_data, { array = true })
  local loclist = {}

  for _, zettel in ipairs(data) do
    table.insert(loclist, {
      filename = zettel.path,
      text = zettel.title,
    })
  end

  vim.fn.setqflist(loclist, "r")
  vim.cmd("copen")
end

zet.history = function()
  local raw_data = exec("zet", { "history" })
  if raw_data == nil then
    return
  end

  local data = vim.json.decode(raw_data, { array = true })
  local loclist = {}

  for _, zettel in ipairs(data) do
    table.insert(loclist, {
      filename = zettel.path,
      text = zettel.title,
    })
  end

  vim.fn.setqflist(loclist, "r")
  vim.cmd("copen")
end

zet.permanent = function(path)
  local raw_data = exec("zet", { "permanent", path })
  if raw_data == nil then
    return
  end
  local zettel = vim.json.decode(raw_data)
  vim.cmd("e " .. zettel.path)
end

zet.fleet = function(path)
  local raw_data = exec("zet", { "fleet", path })
  if raw_data == nil then
    return
  end
  local zettel = vim.json.decode(raw_data)
  vim.cmd("e " .. zettel.path)
end

--------------------------------
-- Commands
--------------------------------

Utils.cmd("ZetGrep", function(opts)
  local query = opts.fargs[1] or ""
  zet.grep(query)
end, { nargs = "?", desc = "Grep zet files" })
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
end, { nargs = "?", desc = "Create a new zet file" })
Utils.cmd("ZetHistory", zet.history, { nargs = 0, desc = "Show the history" })
Utils.cmd("ZetLast", zet.open_last, { nargs = 0, desc = "Open the last zettel" })
Utils.cmd("ZetBrokenLinks", zet.brokenlinks, { nargs = 0, desc = "Find broken links" })
Utils.cmd("ZetBacklog", zet.backlog, { nargs = 0, desc = "Show the backlog" })
Utils.cmd("ZetMakePermanent", function()
  local curr_path = vim.fn.expand("%:p")
  if vim.fn.filereadable(curr_path) == 0 then
    return
  end
  zet.permanent(curr_path)
end, { nargs = 0, desc = "Make a zettel type permanent" })
Utils.cmd("ZetMakeFleet", function()
  local curr_path = vim.fn.expand("%:p")
  if vim.fn.filereadable(curr_path) == 0 then
    return
  end
  zet.fleet(curr_path)
end, { nargs = 0, desc = "Make a zettel type fleet" })

--------------------------------
-- Augroups
--------------------------------

Utils.autocmd({ "BufReadPost" }, {
  pattern = {
    "/home/odas0r/github.com/odas0r/zet/permanent/*.md",
    "/home/odas0r/github.com/odas0r/zet/fleet/*.md",
  },
  callback = function()
    local curr_path_buf = vim.fn.expand("%:p")

    -- if the file doesn't exist, don't do anything
    if vim.fn.filereadable(curr_path_buf) == 0 then
      return
    end

    Job
      :new({
        command = "zet",
        args = { "save", curr_path_buf },
        on_exit = function(j, code)
          if code == 0 then
            local result = j:result()[1]
            local zettel = vim.json.decode(result)
            print("Saved: " .. zettel.title)
          else
            -- show Error message on red
            P("Zet Error: ")
            P(j:stderr_result())
          end
        end,
      })
      :start()
  end,
})

Utils.autocmd({ "BufWritePost" }, {
  pattern = {
    "/home/odas0r/github.com/odas0r/zet/permanent/*.md",
    "/home/odas0r/github.com/odas0r/zet/fleet/*.md",
  },
  callback = function()
    local curr_path_buf = vim.fn.expand("%:p")

    -- if the file doesn't exist, don't do anything
    if vim.fn.filereadable(curr_path_buf) == 0 then
      return
    end

    Job
      :new({
        command = "zet",
        args = { "save", curr_path_buf },
        on_exit = function(j, code)
          if code == 0 then
            local result = j:result()[1]
            local zettel = vim.json.decode(result)

            local timer = Utils.loading_animation("Saving to GitHub...")

            if not zettel or not zettel.title then
              print("Error: Missing zettel data")
              return
            end

            -- Git Add, Commit, and Push
            local git_command = "cd "
              .. os.getenv("HOME")
              .. "/github.com/odas0r/zet && git add . && git commit -m '(save): "
              .. zettel.title
              .. "' && git push"

            Job
              :new({
                command = "bash",
                args = { "-c", git_command },
                on_exit = function(j, code)
                  timer:stop()
                  if code == 0 then
                    print('Saved: "' .. zettel.title .. '"')
                  else
                    local git_error = table.concat(j:stderr_result(), " ")
                    if git_error == "" then
                      git_error = "Unknown Git Error"
                    end
                    P("Git Error: " .. git_error)
                  end
                end,
              })
              :start()
          else
            local zet_error = table.concat(j:stderr_result(), " ")
            if zet_error == "" then
              zet_error = "Unknown Zet Error"
            end
            P("Zet Error: " .. zet_error)
          end
        end,
      })
      :start()
  end,
})

Utils.autocmd({ "VimEnter", "VimLeave" }, {
  pattern = {
    "/home/odas0r/github.com/odas0r/zet/permanent/*.md",
    "/home/odas0r/github.com/odas0r/zet/fleet/*.md",
  },
  callback = function()
    Job
      :new({
        command = "zet",
        args = { "sync" },
        on_exit = function(j, code)
          if code == 0 then
            print("Synced successfully...")
          else
            print("Error: " .. j:stderr_result()[1])
          end
        end,
      })
      :start()
  end,
})

--------------------------------
-- Keymaps
-------------------------------

Utils.map("n", "<leader>zp", "<cmd>ZetGrep<CR>")
Utils.map("n", "<leader>zn", "<cmd>ZetNew<CR>")
Utils.map("n", "<leader>zl", "<cmd>ZetLast<CR>")
Utils.map("n", "<leader>zb", "<cmd>ZetBacklog<CR>")
Utils.map("n", "<leader>zB", "<cmd>ZetBrokenLinks<CR>")
Utils.map("n", "<leader>zh", "<cmd>ZetHistory<CR>")

--------------------------------
-- UI
--------------------------------

function Input(opts)
  local original_list_option = vim.o.list

  vim.o.list = false

  -- create new empty buffer for our window
  local buf = vim.api.nvim_create_buf(false, true)

  -- get the editor's maximum width and height
  local width = vim.api.nvim_get_option_value("columns", {})
  local height = vim.api.nvim_get_option_value("lines", {})

  -- calculate our floating window size
  local win_width = math.ceil(width * 0.25) -- Less width
  local win_height = 1 -- More height

  -- and its starting position
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  -- set some options for our new buffer
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = buf })
  vim.cmd([[
    highlight FloatBorder guifg=GruvboxFg1
    highlight FloatTitle guifg=GruvboxFg1
  ]])

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
  vim.api.nvim_set_option_value("winhighlight", "Normal:FloatBorder", { win = win })
  vim.cmd(string.format("autocmd WinLeave <buffer=%s> :lua vim.api.nvim_win_close(%s, true)", buf, win))

  -- set prompt and make it "centered" by adding leading spaces
  vim.fn.prompt_setprompt(buf, "  ")
  Utils.map("i", "<CR>", function()
    local input = vim.fn.getline("."):sub(3, -1)
    vim.cmd([[q!]])
    opts.callback(input)
  end, { buf = buf })

  Utils.map("i", { "<ESC>", "q", "<C-c>" }, function()
    vim.cmd([[q!]])
  end, { buf = buf })

  vim.cmd([[startinsert!]])
  vim.o.list = original_list_option
end
