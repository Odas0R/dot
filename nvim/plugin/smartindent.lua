local keymap = vim.keymap.set

local function indentWithI()
  if vim.bo.filetype == "" then
    return "i"
  end

  local currentLine = vim.fn.getline(".")

  if vim.fn.strdisplaywidth(currentLine) == 0 then
    return '"_cc'
  else
    return "i"
  end
end

-- NOTE: replaced with "nmac427/guess-indent.nvim"
--
-- keymap("n", "i", function()
--   return indentWithI()
-- end, { expr = true })
