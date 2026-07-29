local M = {}

local response_timeout_ms = 5000

local function json_encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

local function json_decode(value)
  if vim.json and vim.json.decode then
    return vim.json.decode(value)
  end
  return vim.fn.json_decode(value)
end

local function address()
  local value = vim.env.PI_REVIEW_ADDRESS
  return value and value ~= "" and value or nil
end

function M.is_session()
  return vim.env.PI_REVIEW_OVERLAY == "1"
    and address() ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= ""
end

function M.send(payload, on_complete)
  on_complete = on_complete or function() end

  local target = address()
  local token = vim.env.PI_REVIEW_TOKEN
  local chan
  local completed = false

  local function complete(ok, message)
    if completed then
      return
    end
    completed = true

    if chan and chan > 0 then
      pcall(vim.fn.chanclose, chan)
    end

    vim.schedule(function()
      on_complete(ok, message)
    end)
  end

  if not target or not token or token == "" then
    complete(
      false,
      "No live Pi review bridge found. Open Diffview from Pi with /review-diff."
    )
    return
  end

  payload.token = token
  local encoded_ok, encoded = pcall(json_encode, payload)
  if not encoded_ok then
    complete(false, "Could not encode review comments: " .. tostring(encoded))
    return
  end

  local connected, channel = pcall(vim.fn.sockconnect, "tcp", target, {
    rpc = false,
    data_buffered = true,
    on_data = function(_, data)
      local response_text = table.concat(data or {}, "\n")
      if vim.trim(response_text) == "" then
        complete(
          false,
          "Pi review bridge closed without acknowledging the review"
        )
        return
      end

      local decoded_ok, response = pcall(json_decode, response_text)
      if not decoded_ok or type(response) ~= "table" then
        complete(false, "Pi review bridge returned an invalid response")
        return
      end

      if response.ok == true then
        complete(true)
        return
      end

      complete(
        false,
        type(response.error) == "string" and response.error
          or "Pi review bridge rejected the review"
      )
    end,
  })

  if not connected or not channel or channel <= 0 then
    complete(
      false,
      "Could not connect to Pi review bridge: " .. tostring(channel)
    )
    return
  end
  chan = channel

  local sent_ok, sent = pcall(vim.fn.chansend, chan, encoded .. "\n")
  if not sent_ok or sent == 0 then
    complete(false, "Could not send review comments to Pi")
    return
  end

  vim.defer_fn(function()
    complete(false, "Timed out waiting for Pi to acknowledge the review")
  end, response_timeout_ms)
end

return M
