local Window = require("odas0r.plugin.terminal.window")

local v = vim.api
local cmd = vim.cmd

local Terminal = { bufs = {}, last_winid = nil, last_term = nil }

function Terminal:new(window, opt)
  self.window = window or Window:new()
  -- Add terminal options
  self.term_opts = {
    scrollback = 1000,
    on_stderr = function(_, data) end,
    on_exit = function() end,
  }
  return self
end

function Terminal:open(term_number)
  term_number = term_number or 1
  local create_win = not self.window:is_valid()
  local create_buf = self.bufs[term_number] == nil or not v.nvim_buf_is_valid(self.bufs[term_number])

  if create_win then
    self.last_winid = v.nvim_get_current_win()
  end

  -- Window and buffer does not exist
  if create_win and create_buf then
    -- Create new terminal buffer with async job control
    local bufnr = vim.api.nvim_create_buf(false, true)

    -- Set buffer options before creating terminal
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].buflisted = false

    -- Create window with the prepared buffer
    self.window:create(bufnr)

    -- Setup terminal with proper job control
    vim.fn.termopen(vim.o.shell, {
      on_stdout = function(_, data)
        -- Terminal output is handled automatically by Neovim
      end,
      on_stderr = function(_, data)
        if data then
          vim.schedule(function()
            vim.notify("Terminal error: " .. vim.inspect(data), vim.log.levels.ERROR)
          end)
        end
      end,
      on_exit = function(_, code)
        vim.schedule(function()
          if code ~= 0 then
            vim.notify("Process exited with code: " .. code)
          end
        end)
      end,
      -- Enable proper PTY handling
      pty = true,
      -- Ensure environment is copied
      env = vim.fn.environ(),
    })

    self.bufs[term_number] = bufnr

    -- Set terminal-specific window options
    vim.wo[self.window.winid].wrap = true
    vim.wo[self.window.winid].number = true
    vim.wo[self.window.winid].relativenumber = false

    -- Window does not exist but buffer does
  elseif create_win then
    self.window:create(self.bufs[term_number])

    -- Buffer does not exist but window does
  elseif create_buf then
    self.window:focus()
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.fn.termopen(vim.o.shell, {
      pty = true,
      env = vim.fn.environ(),
    })

    self.bufs[term_number] = bufnr

    -- Buffer and window exist
  else
    local curr_term_buf = self.bufs[term_number]
    local last_term_buf = self.bufs[self.last_term]

    if curr_term_buf ~= last_term_buf then
      self.window:set_buf(curr_term_buf)
    end
  end

  self.last_term = term_number

  -- Enter terminal mode safely
  vim.schedule(function()
    local bufnr = self.bufs[term_number]
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    if buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end)

  -- Set up autocmd for better terminal handling
  vim.cmd([[
    augroup TerminalBuffer
      autocmd! * <buffer>
      autocmd TermOpen <buffer> setlocal nonumber norelativenumber signcolumn=no
      autocmd TermOpen <buffer> startinsert
      autocmd BufEnter <buffer> startinsert
    augroup END
  ]])

  -- Set buffer-local options for better performance
  local bufnr = self.bufs[term_number]
  vim.api.nvim_set_option_value("undolevels", -1, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
end

function Terminal:close()
  local current_winid = v.nvim_get_current_win()
  if self.window:is_valid() then
    -- Save terminal state before closing
    local bufnr = self.window:get_bufno()
    self.window:close()

    -- Clean up terminal job if needed
    if vim.fn.jobwait({ bufnr }, 0)[1] == -1 then
      vim.fn.jobstop(bufnr)
    end

    if current_winid == self.window.winid then
      v.nvim_set_current_win(self.last_winid)
    end
  end
end

function Terminal:toggle()
  self.last_term = self.last_term and self.last_term or 1

  local opened = self.window:is_valid()

  if opened then
    self:close()
  else
    self:open(self.last_term)
  end
end

return Terminal
