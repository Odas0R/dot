local keymap = vim.keymap.set

keymap("n", "<leader>r", function()
  local pattern = vim.fn.input("Replace: ")
  pattern = pattern:gsub("/", "\\/")

  local replacement = vim.fn.input("With: ")
  replacement = replacement:gsub("/", "\\/")

  if replacement == "" or pattern == "" then
    return
  end

  vim.cmd("cfdo %s/" .. pattern .. "/" .. replacement .. "/ge")
end, { silent = true })
