local M = {}

function M.is_uri(path)
  return type(path) == "string" and path:match("^%w[%w+.-]*://") ~= nil
end

function M.relative_to(root, file)
  if not file or file == "" then
    return nil
  end

  if not vim.startswith(file, "/") and not M.is_uri(file) then
    return file
  end

  if M.is_uri(file) then
    return file
  end

  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  file = vim.fn.fnamemodify(file, ":p")
  local prefix = root .. "/"
  if vim.startswith(file, prefix) then
    return file:sub(#prefix + 1)
  end

  return file
end

return M
