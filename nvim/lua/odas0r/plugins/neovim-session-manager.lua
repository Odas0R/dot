return {
  "Shatur/neovim-session-manager",
  config = function(_, opts)
    local Path = require("plenary.path")
    local config = require("session_manager.config")

    require("session_manager").setup({
      -- check: https://github.com/Shatur/neovim-session-manager?tab=readme-ov-file#configuration
      sessions_dir = Path:new(vim.fn.stdpath("data"), "sessions"), -- The directory where the session files will be saved.

      -- Define what to do when Neovim is started without arguments. See "Autoload mode" section below.
      autoload_mode = {
        config.AutoloadMode.GitSession,
        config.AutoloadMode.LastSession,
      },
      autosave_last_session_on_exit = true, -- Automatically save last session on exit.
      autosave_last_session_on_switch = true, -- Automatically save last session on switch.
      autosave_ignore_not_normal = true, -- Plugin will not save a session when no buffers are opened, or all of them aren't writable or listed.
      autosave_ignore_dirs = {}, -- A list of directories where the session will not be autosaved.
      autosave_ignore_filetypes = { -- All buffers of these file types will be closed before the session is saved.
        "gitcommit",
        "gitrebase",
      },
      autosave_ignore_buftypes = {}, -- All buffers of these bufer types will be closed before the session is saved.
      autosave_only_in_session = false, -- Always autosaves session. If true, only autosaves after a session is active.
      max_path_length = 80, -- Shorten the display path if length exceeds this threshold. Use 0 if don't want to shorten the path at all.
      load_include_current = false, -- The currently loaded session appears in the load_session UI.
    })
  end,
}
