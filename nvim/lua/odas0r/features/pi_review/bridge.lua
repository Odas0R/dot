local M = {}

local function json_encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

local function target()
  local address = vim.env.PI_REVIEW_ADDRESS
  if address and address ~= "" then
    return "tcp", address
  end

  local socket = vim.env.PI_REVIEW_SOCKET
  if socket and socket ~= "" then
    return "pipe", socket
  end

  return nil, nil
end

function M.is_session()
  local mode, address = target()
  return mode ~= nil
    and address ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= ""
end

function M.send(payload, notify)
  notify = notify or function() end

  local mode, address = target()
  local token = vim.env.PI_REVIEW_TOKEN

  if not mode or not address or not token or token == "" then
    notify(
      "No live Pi review bridge found. Open Diffview from Pi with /review-diff.",
      vim.log.levels.ERROR
    )
    return false
  end

  payload.token = token
  local ok, encoded = pcall(json_encode, payload)
  if not ok then
    notify(
      "Could not encode review comments: " .. tostring(encoded),
      vim.log.levels.ERROR
    )
    return false
  end

  local connected, chan =
    pcall(vim.fn.sockconnect, mode, address, { rpc = false })
  if not connected or not chan or chan <= 0 then
    notify(
      "Could not connect to Pi review bridge: " .. tostring(chan),
      vim.log.levels.ERROR
    )
    return false
  end

  local sent_ok, sent = pcall(vim.fn.chansend, chan, encoded .. "\n")
  if not sent_ok or sent == 0 then
    pcall(vim.fn.chanclose, chan)
    notify("Could not send review comments to Pi", vim.log.levels.ERROR)
    return false
  end

  pcall(vim.fn.chanclose, chan)
  return true
end

return M
