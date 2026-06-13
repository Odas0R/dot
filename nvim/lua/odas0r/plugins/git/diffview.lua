-- GitHub-like unified diffs, but tuned down for gruvbox-dark.
-- Only Diffview-specific groups are changed; global DiffAdd/DiffDelete/etc.
-- stay owned by the colorscheme.
local colors = {
  add_bg = "#2a3328",
  add_inline = "#3a4a32",
  delete_bg = "#3a2828",
  delete_inline = "#4a3030",
  change_bg = "#332f26",
  text_bg = "#4a432e",
  filler_fg = "#7c6f64",
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

local function apply_github_gruvbox_diff_hl()
  vim.api.nvim_set_hl(0, "DiffviewDiffAdd", { bg = colors.add_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffDelete", { bg = colors.delete_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffChange", { bg = colors.change_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffText", { bg = colors.text_bg })

  -- Old side of modified hunks when enhanced_diff_hl is enabled.
  vim.api.nvim_set_hl(0, "DiffviewDiffAddAsDelete", { bg = colors.delete_bg })

  -- Filler lines opposite additions/deletions should disappear into the UI,
  -- not compete with actual changed lines.
  vim.api.nvim_set_hl(0, "DiffviewDiffDeleteDim", {
    fg = colors.filler_fg,
    bg = "NONE",
  })

  -- Intraline highlights: stronger than line bg, still not neon.
  vim.api.nvim_set_hl(0, "DiffviewDiffAddInline", { bg = colors.add_inline })
  vim.api.nvim_set_hl(0, "DiffviewDiffDeleteInline", {
    fg = colors.red,
    bg = colors.delete_inline,
    strikethrough = true,
  })

  -- File panel/status colors: GitHub-ish green/red/yellow without background blocks.
  vim.api.nvim_set_hl(0, "DiffviewStatusAdded", { fg = colors.green })
  vim.api.nvim_set_hl(0, "DiffviewStatusUntracked", { fg = colors.green })
  vim.api.nvim_set_hl(0, "DiffviewStatusModified", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "DiffviewStatusRenamed", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "DiffviewStatusDeleted", { fg = colors.red })
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
      "<leader>do",
      "<cmd>DiffviewOpen --imply-local<cr>",
      desc = "Review working tree",
    },
    {
      "<leader>db",
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
          "<leader>c",
          "<cmd>PiReviewComment<cr>",
          { desc = "Add Pi review comment" },
        },
        {
          "x",
          "<leader>c",
          ":<C-U>'<,'>PiReviewComment<cr>",
          { desc = "Add Pi review comment" },
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
      view_opened = apply_github_gruvbox_diff_hl,
      view_enter = apply_github_gruvbox_diff_hl,
    },
  },
  config = function(_, opts)
    require("diffview").setup(opts)

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup(
        "odas0r_diffview_highlights",
        { clear = true }
      ),
      callback = apply_github_gruvbox_diff_hl,
    })
  end,
}
