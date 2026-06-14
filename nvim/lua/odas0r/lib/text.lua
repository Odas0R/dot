local M = {}

function M.truncate(value, max_width)
  value = value or ""
  if vim.fn.strdisplaywidth(value) <= max_width then
    return value
  end
  return vim.fn.strcharpart(value, 0, math.max(max_width - 1, 0)) .. "…"
end

function M.plural(count, singular, plural_word)
  if count == 1 then
    return singular
  end
  return plural_word or (singular .. "s")
end

return M
