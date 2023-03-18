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

local function write_to_temp_file(lines)
  local temp_file_name = os.tmpname()
  local file, err = io.open(temp_file_name, "w")
  assert(file, err)
  for _, line in ipairs(lines) do
    file:write(line .. "\n")
  end
  file:close()
  return temp_file_name
end

local function read_temp_file_lines(temp_file_name)
  local lines = {}
  for line in io.lines(temp_file_name) do
    lines[#lines + 1] = line
  end
  return lines
end

describe("Replace Module", function()
  before_each(function()
    vim.cmd([[
      enew
    ]])
  end)

  it("should not modify lines without a matching pattern", function()
    -- create a file with some lines
    local file_path = write_to_temp_file({ "hello world", "world of code" })
    local bufnr = vim.fn.bufadd(file_path)

    populate_quickfix_list({
      { bufnr = bufnr, words = { "hello world", "world of code" } },
    })

    vim.cmd([[Replace nonexistent NVIM]])

    local lines = read_temp_file_lines(file_path)
    assert.are.same({ "hello world", "world of code" }, lines)

    os.remove(file_path)
  end)

  it("should replace matching patterns with the given replacement", function()
    -- create a file with some lines
    local file_path = write_to_temp_file({ "hello world", "world of code" })
    local bufnr = vim.fn.bufadd(file_path)

    populate_quickfix_list({
      { bufnr = bufnr, words = { "hello world", "world of code" } },
    })

    vim.cmd([[Replace world NVIM]])

    local lines = read_temp_file_lines(file_path)
    assert.are.same({ "hello NVIM", "NVIM of code" }, lines)

    os.remove(file_path)
  end)

  it("should replace matching patterns with the given replacement in multiple buffers", function()
    local file_path1 = write_to_temp_file({ "hello world", "world of code", "code world" })
    local buf1 = vim.fn.bufadd(file_path1)

    local file_path2 = write_to_temp_file({ "world domination", "world peace", "world of music" })
    local buf2 = vim.fn.bufadd(file_path2)

    local file_path3 = write_to_temp_file({ "another world", "world of art", "world of science" })
    local buf3 = vim.fn.bufadd(file_path3)

    populate_quickfix_list({
      { bufnr = buf1, words = { "hello world", "world of code", "code world" } },
      { bufnr = buf2, words = { "world domination", "world peace", "world of music" } },
      { bufnr = buf3, words = { "another world", "world of art", "world of science" } },
    })

    vim.cmd([[Replace world NVIM]])

    -- Check if the replacement occurred correctly in all buffers
    local lines1 = read_temp_file_lines(file_path1)
    local lines2 = read_temp_file_lines(file_path2)
    local lines3 = read_temp_file_lines(file_path3)

    assert.are.same({ "hello NVIM", "NVIM of code", "code NVIM" }, lines1)
    assert.are.same({ "NVIM domination", "NVIM peace", "NVIM of music" }, lines2)
    assert.are.same({ "another NVIM", "NVIM of art", "NVIM of science" }, lines3)

    os.remove(file_path1)
    os.remove(file_path2)
    os.remove(file_path3)
  end)

  it("should replace complex patterns with given replacement, handling whitespace correctly", function()
    local file_path = write_to_temp_file({

      "lorem ipsum &^%$*#@! dolor",
      "sit amet, consectetur adipiscing",
      "elit, 1234567890 sed do eiusmod tempor",
      "incididunt ut   labore et dolore magna aliqua.",
    })

    local buf = vim.fn.bufadd(file_path)

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
    local lines = read_temp_file_lines(file_path)
    assert.are.same({
      "lorem ipsum &^%$*#@! dolor",
      "sit amet, consectetur adipiscing",
      "elit, 1234567890 sed do eiusmod tempor",
      "incididunt UT LABORE et dolore magna aliqua.",
    }, lines)

    os.remove(file_path)
  end)

  it("should return an empty list if no matches are found", function()
    populate_quickfix_list({ { bufnr = 0, words = { "apple", "banana", "cherry" } } })

    local result = replace.autocomplete("grape")
    assert.are.same({}, result)
  end)

  it("should return matching words from the quickfix list", function()
    populate_quickfix_list({ { bufnr = 0, words = { "apple", "banana", "cherry", "grape" } } })

    local qflist = vim.fn.getqflist()
    local unique_words = replace.get_unique_words(qflist)

    assert.are.same({ "apple", "banana", "cherry", "grape" }, unique_words)

    local result

    result = replace.autocomplete("ap")
    assert.are.same({ "apple" }, result)

    result = replace.autocomplete("cher")
    assert.are.same({ "cherry" }, result)
  end)
end)
