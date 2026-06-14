local Store = {}
Store.__index = Store

function Store.new()
  return setmetatable({
    comments = {},
    next_id = 1,
  }, Store)
end

function Store:count()
  return #self.comments
end

function Store:all()
  return self.comments
end

function Store:reset_ids()
  for index, comment in ipairs(self.comments) do
    comment.id = index
  end
  self.next_id = #self.comments + 1
end

function Store:add(comment)
  comment.id = self.next_id
  self.next_id = self.next_id + 1
  table.insert(self.comments, comment)
  return comment
end

function Store:find(id)
  for _, comment in ipairs(self.comments) do
    if comment.id == id then
      return comment
    end
  end
  return nil
end

function Store:clear(id)
  for index, comment in ipairs(self.comments) do
    if comment.id == id then
      table.remove(self.comments, index)
      self:reset_ids()
      return comment
    end
  end
  return nil
end

function Store:clear_many(ids)
  local pending = {}
  for _, id in ipairs(ids) do
    pending[id] = true
  end

  local removed = 0
  for index = #self.comments, 1, -1 do
    if pending[self.comments[index].id] then
      table.remove(self.comments, index)
      removed = removed + 1
    end
  end

  if removed > 0 then
    self:reset_ids()
  end

  return removed
end

function Store:clear_all()
  self.comments = {}
  self.next_id = 1
end

function Store:payload()
  return {
    scope = "batch",
    comments = vim.deepcopy(self.comments),
  }
end

return Store
