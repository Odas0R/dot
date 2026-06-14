-- Gruvbox-dark diffs with enough contrast to scan quickly without becoming
-- neon. Line backgrounds are visible; intraline highlights are stronger.
-- Global DiffAdd/DiffDelete/etc. stay owned by the colorscheme.
local colors = {
  fg = "#ebdbb2",
  add_bg = "#323d2b",
  add_inline = "#475936",
  delete_bg = "#442c2c",
  delete_inline = "#5a3535",
  change_bg = "#3f3728",
  change_inline = "#5a4a2f",
  filler_fg = "#928374",
  green = "#b8bb26",
  red = "#fb4934",
  yellow = "#fabd2f",
}

local function diff_branch_against_head()
  vim.ui.input({
    prompt = "Diff against branch: ",
    default = "origin/main",
  }, function(branch)
    branch = branch and vim.trim(branch) or ""
    if branch == "" then
      return
    end

    vim.cmd(
      ("DiffviewOpen %s...HEAD --imply-local"):format(
        vim.fn.fnameescape(branch)
      )
    )
  end)
end

local function is_diffview_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local filetype = vim.bo[buf].filetype
  return filetype == "DiffviewFiles"
    or filetype == "DiffviewFileHistory"
    or vim.b[buf].diffview_loaded
    or vim.api.nvim_buf_get_name(buf):match("^diffview://") ~= nil
end

local function disable_diffview_relative_number()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_diffview_buffer(buf) then
      vim.wo[win].relativenumber = false
    end
  end
end

local function apply_soft_gruvbox_diff_hl()
  vim.api.nvim_set_hl(0, "DiffviewDiffAdd", { bg = colors.add_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffDelete", { bg = colors.delete_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffChange", { bg = colors.change_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffText", { bg = colors.change_inline })

  -- Old side of modified hunks when enhanced_diff_hl is enabled.
  vim.api.nvim_set_hl(0, "DiffviewDiffAddAsDelete", { bg = colors.delete_bg })

  -- Filler lines opposite additions/deletions should disappear into the UI,
  -- not compete with actual changed lines.
  vim.api.nvim_set_hl(0, "DiffviewDiffDeleteDim", {
    fg = colors.filler_fg,
    bg = "NONE",
  })

  -- Intraline highlights: stronger than line bg, still not neon. Diffview
  -- derives DiffviewDiffTextInline from global DiffText, which gruvbox makes
  -- bright yellow with dark text; override it to avoid black/yellow patches in
  -- modified hunks.
  vim.api.nvim_set_hl(0, "DiffviewDiffAddInline", { bg = colors.add_inline })
  vim.api.nvim_set_hl(0, "DiffviewDiffTextInline", {
    bg = colors.change_inline,
  })
  vim.api.nvim_set_hl(0, "DiffviewDiffDeleteInline", {
    fg = colors.fg,
    bg = colors.delete_inline,
    strikethrough = true,
  })

  -- File panel/status colors: muted green/red/yellow without background blocks.
  vim.api.nvim_set_hl(0, "DiffviewStatusAdded", { fg = colors.green })
  vim.api.nvim_set_hl(0, "DiffviewStatusUntracked", { fg = colors.green })
  vim.api.nvim_set_hl(0, "DiffviewStatusModified", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "DiffviewStatusRenamed", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "DiffviewStatusDeleted", { fg = colors.red })
end

local function apply_diffview_ui()
  apply_soft_gruvbox_diff_hl()
  disable_diffview_relative_number()
end

return {
  "dlyongemallo/diffview-plus.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewToggle",
    "DiffviewFileHistory",
    "DiffviewDiffFiles",
    "DiffviewMergeFiles",
    "DiffviewDiffDirs",
    "DiffviewLog",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    {
      "<leader>dr",
      "<cmd>DiffviewOpen --imply-local<cr>",
      desc = "Review working tree",
    },
    {
      "<leader>dR",
      diff_branch_against_head,
      desc = "Review branch vs chosen base",
    },
    { "<leader>dc", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    {
      "<leader>df",
      "<cmd>DiffviewFileHistory %<cr>",
      desc = "Current file history",
    },
    {
      "<leader>dh",
      "<cmd>DiffviewFileHistory<cr>",
      desc = "Repository history",
    },
  },
  opts = {
    enhanced_diff_hl = true,
    use_icons = false,
    default_args = {
      DiffviewOpen = { "--imply-local" },
    },
    file_panel = {
      listing_style = "tree",
      show_branch_name = true,
      always_show_sections = true,
    },
    persist_selections = { enabled = true },
    diffopt = { algorithm = "histogram", linematch = 60 },
    view = {
      default = {
        -- GitHub-like review: one unified diff pane instead of side-by-side.
        layout = "diff2_horizontal",
        winbar_info = true,
      },
      file_history = {
        layout = "diff1_inline",
        winbar_info = true,
      },
      merge_tool = {
        -- Keep merge resolution spatial; unified diffs are for review, not conflicts.
        layout = "diff3_mixed",
        winbar_info = true,
      },
      cycle_layouts = {
        default = { "diff1_inline", "diff2_horizontal", "diff2_vertical" },
        merge_tool = {
          "diff3_mixed",
          "diff4_mixed",
          "diff3_horizontal",
          "diff3_vertical",
          "diff1_plain",
        },
      },
      inline = {
        style = "unified",
        deletion_highlight = "hanging",
        deletion_treesitter = true,
      },
      one_sided_layout = "raw",
    },
    keymaps = {
      view = {
        {
          "n",
          "<leader>q",
          "<cmd>DiffviewClose<cr>",
          { desc = "Close Diffview" },
        },
        {
          "n",
          "<leader>r",
          "<cmd>DiffviewRefresh<cr>",
          { desc = "Refresh Diffview" },
        },
      },
      file_panel = {
        {
          "n",
          "<leader>q",
          "<cmd>DiffviewClose<cr>",
          { desc = "Close Diffview" },
        },
      },
      file_history_panel = {
        {
          "n",
          "<leader>q",
          "<cmd>DiffviewClose<cr>",
          { desc = "Close Diffview" },
        },
      },
    },
    hooks = {
      view_opened = apply_diffview_ui,
      view_enter = apply_diffview_ui,
    },
  },
  config = function(_, opts)
    -- diffview-plus registers a SessionLoadPost cleanup for session-restored
    -- diffview:// buffers. When the plugin is lazy-loaded by :DiffviewOpen
    -- during session-manager autoload, that scheduled cleanup can run in the
    -- middle of panel creation and wipe the just-created file-panel buffer.
    -- Disable it until the plugin protects live panel buffers itself.
    pcall(vim.api.nvim_del_augroup_by_name, "diffview_session")

    require("diffview").setup(opts)

    apply_diffview_ui()

    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup(
        "odas0r_diffview_window_options",
        { clear = true }
      ),
      pattern = {
        "DiffviewViewOpened",
        "DiffviewViewEnter",
        "DiffviewViewPostLayout",
        "DiffviewDiffBufWinEnter",
      },
      callback = function()
        vim.schedule(disable_diffview_relative_number)
      end,
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup(
        "odas0r_diffview_highlights",
        { clear = true }
      ),
      callback = apply_diffview_ui,
    })
  end,
}
