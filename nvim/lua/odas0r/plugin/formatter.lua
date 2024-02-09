local Utils = require("odas0r.utils")

local M = {}

local function is_extension(extensions)
  local current_file = vim.fn.expand("%:e")
  for _, extension in ipairs(extensions) do
    if current_file == extension then
      return true
    end
  end
  return false
end

M.init = function()
  Utils.map("n", "gp", function()
    vim.cmd("FormatWrite")
  end, { silent = false })
end

M.config = function()
  local formatter = require("formatter")
  local util = require("formatter.util")

  local prettierConfig = function()
    -- if is_extension({ "json", "jsonc", "md" }) then
    --   return nil
    -- end

    -- set env variable
    return {
      exe = "prettier",
      args = {
        "--stdin-filepath",
        util.escape_path(util.get_current_buffer_file_path()),
      },
      stdin = true,
      try_node_modules = true,
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
    jsonc = {
      function()
        return {
          exe = "fixjson",
          args = { "-w" },
          stdin = true,
        }
      end,
      prettierConfig,
    },
    dart = {
      -- function()
      --   return {
      --     exe = "dart",
      --     args = { "fix", "--apply" },
      --     stdin = true,
      --   }
      -- end,
      function()
        return {
          exe = "dart",
          args = { "format" },
          stdin = true,
        }
      end,
    },
    go = {
      function()
        return {
          exe = "goimports",
          stdin = true,
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
    "mdx",
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
    -- Set the log level
    log_level = vim.log.levels.WARN,
    filetype = formatterConfig,
  })
end

return M
