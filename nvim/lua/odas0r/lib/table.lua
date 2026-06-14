local M = {}

function M.merge(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(t1[k] or false) == "table" then
      M.merge(t1[k], t2[k])
    else
      t1[k] = v
    end
  end

  return t1
end

function M.reverse(t)
  local len = #t + 1
  for i = 1, math.floor(#t / 2) do
    t[i], t[len - i] = t[len - i], t[i]
  end
  return t
end

return M
