local Utils = require("odas0r.utils")

return {
  "mhartington/formatter.nvim",
  cmd = "FormatWrite",
  init = function()
    Utils.map("n", "gp", function()
      vim.cmd("FormatWrite")
    end, { silent = false })
  end,
  config = function()
    local formatter = require("formatter")

    local prettierConfig = function()
      -- if is_extension({ "json", "jsonc", "md" }) then
      --   return nil
      -- end

      -- set env variable
      -- return {
      --   exe = "prettier",
      --   args = {
      --     "--stdin-filepath",
      --     util.escape_path(util.get_current_buffer_file_path()),
      --   },
      --   stdin = true,
      --   try_node_modules = true,
      -- }

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
            exe = "autoimport",
            stdin = false,
          }
        end,
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
  end,
}
