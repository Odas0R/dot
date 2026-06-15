local function has_luarc(path)
  return vim.uv.fs_stat(vim.fs.joinpath(path, ".luarc.json"))
    or vim.uv.fs_stat(vim.fs.joinpath(path, ".luarc.jsonc"))
end

local function workspace_library()
  local library = {
    vim.env.VIMRUNTIME,
    vim.fn.stdpath("config"),
  }

  local lspconfig_annotations =
    vim.api.nvim_get_runtime_file("lua/lspconfig", false)[1]
  if lspconfig_annotations then
    table.insert(library, lspconfig_annotations)
  end

  local busted_stubs =
    vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "busted-stubs")
  if vim.uv.fs_stat(busted_stubs) then
    table.insert(library, busted_stubs)
  end

  return library
end

return {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name

      -- Prefer project-local LuaLS settings when they exist. The Neovim-specific
      -- runtime/workspace below is only a fallback for nvim config/plugin work.
      if path ~= vim.fn.stdpath("config") and has_luarc(path) then
        return
      end
    end

    client.config.settings = client.config.settings or {}
    client.config.settings.Lua =
      vim.tbl_deep_extend("force", client.config.settings.Lua or {}, {
        runtime = {
          version = "LuaJIT",
          path = {
            "lua/?.lua",
            "lua/?/init.lua",
          },
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          checkThirdParty = false,
          library = workspace_library(),
        },
      })
  end,
  settings = {
    Lua = {
      telemetry = {
        enable = false,
      },
    },
  },
}
