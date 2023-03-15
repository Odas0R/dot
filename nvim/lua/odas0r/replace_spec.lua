local replace = require("replace")

local set_quickfix_list = function(entries)
  vim.fn.setqflist({}, " ", { title = "Test Quickfix List", items = entries })
end

local function populate_quickfix_list(buffer_data)
  local entries = {}
  for _, data in ipairs(buffer_data) do
    local bufnr = data.bufnr
    local words = data.words
    for i, word in ipairs(words) do
      table.insert(entries, { bufnr = bufnr, lnum = i, col = 1, text = word })
    end
  end
  set_quickfix_list(entries)
end

describe("Replace Module", function()
  before_each(function()
    vim.cmd([[
      enew
    ]])
  end)

  it("should not modify lines without a matching pattern", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world", "world of code" })
    populate_quickfix_list({
      { bufnr = 0, words = { "hello world", "world of code" } },
    })

    vim.cmd([[Replace nonexistent NVIM]])

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ "hello world", "world of code" }, lines)
  end)

  it("should replace matching patterns with the given replacement", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world", "world of code" })
    populate_quickfix_list({
      { bufnr = 0, words = { "hello world", "world of code" } },
    })

    vim.cmd([[Replace world NVIM]])

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ "hello NVIM", "NVIM of code" }, lines)
  end)

  it("should replace matching patterns with the given replacement in multiple buffers", function()
    -- Create three buffers with different contents
    local buf1 = vim.api.nvim_create_buf(false, true)
    local buf2 = vim.api.nvim_create_buf(false, true)
    local buf3 = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "hello world", "world of code", "code world" })
    vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "world domination", "world peace", "world of music" })
    vim.api.nvim_buf_set_lines(buf3, 0, -1, false, { "another world", "world of art", "world of science" })

    populate_quickfix_list({
      { bufnr = buf1, words = { "hello world", "world of code", "code world" } },
      { bufnr = buf2, words = { "world domination", "world peace", "world of music" } },
      { bufnr = buf3, words = { "another world", "world of art", "world of science" } },
    })

    vim.cmd([[Replace world NVIM]])

    -- Check if the replacement occurred correctly in all buffers
    local lines1 = vim.api.nvim_buf_get_lines(buf1, 0, -1, false)
    local lines2 = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
    local lines3 = vim.api.nvim_buf_get_lines(buf3, 0, -1, false)

    assert.are.same({ "hello NVIM", "NVIM of code", "code NVIM" }, lines1)
    assert.are.same({ "NVIM domination", "NVIM peace", "NVIM of music" }, lines2)
    assert.are.same({ "another NVIM", "NVIM of art", "NVIM of science" }, lines3)
  end)

  it("should replace complex patterns with given replacement, handling whitespace correctly", function()
    -- Create a buffer with complex text
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "lorem ipsum &^%$*#@! dolor",
      "sit amet, consectetur adipiscing",
      "elit, 1234567890 sed do eiusmod tempor",
      "incididunt ut   labore et dolore magna aliqua.",
    })

    populate_quickfix_list({
      {
        bufnr = buf,
        words = {
          "lorem ipsum &^%$*#@! dolor",
          "sit amet, consectetur adipiscing",
          "elit, 1234567890 sed do eiusmod tempor",
          "incididunt ut   labore et dolore magna aliqua.",
        },
      },
    })

    vim.cmd([[Replace 'ut   labore' 'UT LABORE']])

    -- Check if the replacement occurred correctly in the buffer
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.are.same({
      "lorem ipsum &^%$*#@! dolor",
      "sit amet, consectetur adipiscing",
      "elit, 1234567890 sed do eiusmod tempor",
      "incididunt UT LABORE et dolore magna aliqua.",
    }, lines)
  end)

  it("should return an empty list if no matches are found", function()
    populate_quickfix_list({ { bufnr = 0, words = { "apple", "banana", "cherry" } } })

    local result = replace.autocomplete("grape")
    assert.are.same("", result)
  end)

  it("should return matching words from the quickfix list", function()
    populate_quickfix_list({ { bufnr = 0, words = { "apple", "banana", "cherry", "grape" } } })

    local qflist = vim.fn.getqflist()
    local unique_words = replace.get_unique_words(qflist)

    assert.are.same({ "apple", "banana", "cherry", "grape" }, unique_words)

    local result

    result = replace.autocomplete("ap")
    assert.are.same("apple", result)

    result = replace.autocomplete("cher")
    print(result)
    assert.are.same("cherry", result)
  end)
end)
