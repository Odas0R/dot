local vim = vim
local formatter = require("formatter")

local prettierConfig = function()
  return {
    exe = "prettier",
    args = { "--stdin-filepath", vim.fn.shellescape(vim.api.nvim_buf_get_name(0)), "--double-quote" },
    stdin = true,
  }
end

local formatterConfig = {
  lua = {
    function()
      return {
        exe = "stylua",
        args = {
          "--indent-type",
          "Spaces",
          "--indent-width",
          2,
        },
        stdin = false,
      }
    end,
  },
  python = {
    function()
      return {
        exe = "python3 -m autopep8",
        args = {
          "--in-place --aggressive --aggressive",
          vim.fn.fnameescape(vim.api.nvim_buf_get_name(0)),
        },
        stdin = false,
      }
    end,
  },
  sh = {
    -- Shell Script Formatter
    function()
      return {
        exe = "shfmt",
        args = { "-i", 2 },
        stdin = true,
      }
    end,
  },
  json = {
    function()
      return {
        exe = "fixjson",
        args = { "-w" },
        stdin = true,
      }
    end,
    prettierConfig,
  },
  go = {
    function()
      return {
        exe = "goimports",
        args = { "-w" },
        stdin = false,
      }
    end,
    function()
      return {
        exe = "gofmt",
        stdin = true,
      }
    end,
  },
  ["*"] = {
    function()
      return {
        -- remove trailing whitespace
        exe = "sed",
        args = { "-i", "'s/[ \t]*$//'" },
        stdin = false,
      }
    end,
  },
}

local commonFT = {
  "css",
  "scss",
  "html",
  "java",
  "markdown",
  "markdown.mdx",
  "yaml",
  "xml",
  "svg",
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
}
for _, ft in ipairs(commonFT) do
  formatterConfig[ft] = { prettierConfig }
end
-- Setup functions
formatter.setup({
  logging = true,
  filetype = formatterConfig,
})
