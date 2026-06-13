return {
  "dlyongemallo/diffview-plus.nvim",
  version = "*",
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
      "<cmd>DiffviewOpen origin/main...HEAD --imply-local<cr>",
      desc = "Review branch vs origin/main",
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
  },
}
