local vim = vim
local formatter = require("formatter")

-- local function fileExists(path)
--   local stat = vim.loop.fs_stat(path)
--   return stat and (stat.type == "file" or stat.type == "directory")
-- end

-- local function isGitRoot(path)
--   return fileExists(path .. "/.git")
-- end

-- local function findConfigFile(configFiles, path)
--   for _, configFile in ipairs(configFiles) do
--     if fileExists(path .. "/" .. configFile) then
--       return path .. "/" .. configFile
--     end
--   end
--   return nil
-- end

-- local function getParentDir(path)
--   return vim.fn.fnamemodify(path, ":h")
-- end

-- local function recursivePath(configFiles)
--   local path = vim.api.nvim_buf_get_name(0) -- Get the current file path
--
--   print("haha ", path)
--
--   while not isGitRoot(path) do
--     local configFile = findConfigFile(configFiles, path)
--     if configFile then
--       return configFile
--     end
--
--     local parent = getParentDir(path)
--     if parent == path then
--       break
--     end
--     path = parent
--   end
--   return nil
-- end

-- print(recursivePath({ ".prettierrc", "prettier.config.cjs", ".prettierrc.cjs" }))

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
local keymap = vim.keymap.set

vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    vim.cmd([[
      checktime
    ]])
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    keymap("n", "gp", "<cmd>FormatWrite<CR>", { silent = true })
  end,
})
