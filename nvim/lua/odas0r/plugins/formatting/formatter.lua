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

    local findBiome = function()
      local filePath = fmtUtil.get_current_buffer_file_path()
      local searchPath = filePath ~= "" and vim.fs.dirname(filePath)
        or fmtUtil.get_cwd()
      local biomeBin = vim.fn.has("win32") == 1 and "biome.cmd" or "biome"

      for dir in vim.fs.parents(vim.fs.normalize(searchPath) .. "/") do
        local localBiome = dir .. "/node_modules/.bin/" .. biomeBin
        if vim.fn.executable(localBiome) == 1 then
          return localBiome
        end
      end

      local globalBiome = vim.fn.exepath("biome")
      if globalBiome ~= "" then
        return globalBiome
      end
    end

    local biomeConfig = function()
      local biome = findBiome()
      if not biome then
        vim.notify(
          "biome not found in any parent node_modules/.bin or PATH. Install @biomejs/biome.",
          vim.log.levels.WARN
        )
        return nil
      end

      return {
        exe = fmtUtil.escape_path(biome),
        args = {
          "format",
          "--stdin-file-path",
          fmtUtil.escape_path(fmtUtil.get_current_buffer_file_path()),
        },
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
