local map = require("odas0r.lib.keymap")

return {
  "mhartington/formatter.nvim",
  cmd = "FormatWrite",
  init = function()
    map("n", "gp", function()
      vim.cmd("FormatWrite")
    end, { silent = false })
  end,

  config = function()
    local fmtUtil = require("formatter.util")
    local formatter = require("formatter")

    local biomeConfig = function()
      return {
        exe = "biome",
        args = {
          "format",
          "--stdin-file-path",
          fmtUtil.escape_path(fmtUtil.get_current_buffer_file_path()),
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
            exe = "autopep8",
            args = {
              "--in-place --aggressive",
            },
            stdin = false,
          }
        end,
      },
      sh = {
        function()
          return {
            exe = "shfmt",
            args = { "-i", 2 },
            stdin = true,
          }
        end,
      },
      bash = {
        function()
          return {
            exe = "shfmt",
            args = { "-i", 2 },
            stdin = true,
          }
        end,
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
      templ = {
        function()
          return {
            exe = "templ",
            args = {
              "fmt",
            },
            stdin = false,
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

    local biomeFT = {
      "astro",
      "css",
      "graphql",
      "javascript",
      "javascriptreact",
      "json",
      "jsonc",
      "typescript",
      "typescriptreact",
    }
    for _, ft in ipairs(biomeFT) do
      formatterConfig[ft] = { biomeConfig }
    end
    -- Setup functions
    formatter.setup({
      logging = true,
      -- Set the log level
      log_level = vim.log.levels.WARN,
      filetype = formatterConfig,
    })
  end,
}
