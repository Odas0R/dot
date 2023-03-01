local vim = vim
local formatter = require("formatter")
local util = require("formatter.util")

-- local prettierConfig = function()
--   return {
--     exe = "prettier",
--     args = {
--       "--stdin-filepath",
--       util.escape_path(util.get_current_buffer_file_path()),
--     },
--     stdin = true,
--     try_node_modules = true,
--   }
-- end

-- Trying out the faster prettier_d https://github.com/fsouza/prettierd
local prettierConfig = function()
  return {
    exe = "prettierd",
    args = { vim.api.nvim_buf_get_name(0) },
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
          "--in-place --aggressive",
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
  caddyfile = {
    function()
      return {
        exe = "caddy",
        args = {
          "fmt",
        },
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
  "toml",
  "markdown",
  "markdown.mdx",
  "yaml",
  "xml",
  "svg",
  "astro",
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

-----------------------------------
-- Augroup Formatter
-----------------------------------

local group = vim.api.nvim_create_augroup("Formatter", { clear = true })
vim.api.nvim_create_autocmd("FocusGained", {
  command = "checktime",
  group = group,
})

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "gp", "<cmd>FormatWrite<CR>", { noremap = true, silent = true })
  end,
  group = group,
})
