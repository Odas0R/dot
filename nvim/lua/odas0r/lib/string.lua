local M = {}

function M.slugify(str)
  str = string.lower(str)
  str = string.gsub(str, " ", "-")
  str = string.gsub(str, "[^a-z0-9-]", "")
  str = string.gsub(str, "-$", "")

  return str
end

function M.is_not_empty(str)
  return str ~= nil and str ~= "" or false
end

return M
