local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }

  if opts then
    if opts.buf then
      opts.buffer = opts.buf
      opts.buf = nil
    elseif opts.bufr then
      opts.buffer = opts.bufr
      opts.bufr = nil
    elseif opts.bufnr then
      opts.buffer = opts.bufnr
      opts.bufnr = nil
    end

    options = vim.tbl_extend("force", options, opts)
  end

  if vim.islist(lhs) then
    for _, key in ipairs(lhs) do
      vim.keymap.set(mode, key, rhs, options)
    end
  else
    vim.keymap.set(mode, lhs, rhs, options)
  end
end

return map
