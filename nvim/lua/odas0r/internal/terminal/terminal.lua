local Window = require("odas0r.internal.terminal.window")

local api = vim.api

local Terminal = {
  bufs = {},
  job_ids = {},
  last_winid = nil,
  last_term = 1,
}

function Terminal:new(window)
  self.window = window or Window:new()
  return self
end

function Terminal:_create_buf()
  local bufnr = api.nvim_create_buf(false, true)
  -- Set buffer options
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = "terminal"
  return bufnr
end

function Terminal:_spawn_shell(bufnr, term_number)
  local opts = {
    on_stdout = function(_, data)
      -- Terminal output is handled automatically by Neovim
    end,
    on_stderr = function(_, data)
      if data then
        local valid_data = false
        for _, line in ipairs(data) do
          if line ~= "" then
            valid_data = true
            break
          end
        end
        if valid_data then
          -- Optional: Log errors or silently ignore if they are just shell noise
          -- vim.notify("Terminal stderr: " .. vim.inspect(data), vim.log.levels.WARN)
        end
      end
    end,
    on_exit = function(_, code)
      self.job_ids[term_number] = nil
      if code ~= 0 then
        vim.schedule(function()
          vim.notify("Terminal process exited with code: " .. code, vim.log.levels.INFO)
        end)
      end
    end,
    pty = true,
    env = vim.fn.environ(),
  }

  local job_id = vim.fn.termopen(vim.o.shell, opts)
  self.job_ids[term_number] = job_id
  self.bufs[term_number] = bufnr

  -- Buffer local settings
  vim.api.nvim_set_option_value("undolevels", -1, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  -- Setup autocmds for this buffer
  local grp = api.nvim_create_augroup("TerminalBuffer_" .. bufnr, { clear = true })
  api.nvim_create_autocmd("TermOpen", {
    buffer = bufnr,
    group = grp,
    command = "setlocal nonumber norelativenumber signcolumn=no cursorline=no | startinsert",
  })
  api.nvim_create_autocmd("BufEnter", {
    buffer = bufnr,
    group = grp,
    command = "startinsert",
  })
  api.nvim_create_autocmd("TermLeave", {
    buffer = bufnr,
    group = grp,
    command = "stopinsert",
  })
end

function Terminal:open(term_number)
  term_number = term_number or 1
  self.last_term = term_number

  local win_valid = self.window:is_valid()
  local buf_valid = self.bufs[term_number] and api.nvim_buf_is_valid(self.bufs[term_number])

  if not win_valid then
    self.last_winid = api.nvim_get_current_win()
  end

  -- Case 1: No Window, No Buffer (or invalid buffer)
  if not win_valid and not buf_valid then
    local bufnr = self:_create_buf()
    self.window:create(bufnr)
    self:_spawn_shell(bufnr, term_number)

  -- Case 2: No Window, Valid Buffer
  elseif not win_valid and buf_valid then
    self.window:create(self.bufs[term_number])
    -- Re-enter insert mode
    vim.cmd("startinsert")

  -- Case 3: Window exists, No Buffer
  elseif win_valid and not buf_valid then
    self.window:focus()
    local bufnr = self:_create_buf()
    self.window:set_buf(bufnr)
    self:_spawn_shell(bufnr, term_number)

  -- Case 4: Both exist
  else
    if self.window:get_bufno() ~= self.bufs[term_number] then
      self.window:set_buf(self.bufs[term_number])
    end
    self.window:focus()
    vim.cmd("startinsert")
  end

  -- Ensure window options are set
  local winid = self.window.winid
  if winid and api.nvim_win_is_valid(winid) then
    vim.wo[winid].wrap = true
    vim.wo[winid].number = true
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = "no"
  end
end

function Terminal:close()
  local current_winid = api.nvim_get_current_win()
  if self.window:is_valid() then
    self.window:close()
    if current_winid == self.window.winid and self.last_winid and api.nvim_win_is_valid(self.last_winid) then
      api.nvim_set_current_win(self.last_winid)
    end
  end
end

function Terminal:toggle()
  if self.window:is_valid() then
    self:close()
  else
    self:open(self.last_term or 1)
  end
end

function Terminal:send(cmd, term_number)
  term_number = term_number or self.last_term or 1

  -- Ensure terminal is open and focused
  self:open(term_number)

  local job_id = self.job_ids[term_number]
  if job_id then
    api.nvim_chan_send(job_id, cmd .. "\r")
    vim.cmd("normal! G")
    vim.cmd("startinsert")
  else
    vim.notify("Terminal job not found. Please restart terminal.", vim.log.levels.ERROR)
  end
end

return Terminal
