return {
  "odas0r/pi-review.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/odas0r/features/pi_review",
  cmd = {
    "PiReviewComment",
    "PiReviewFileComment",
    "PiReviewList",
    "PiSubmitReview",
  },
  keys = {
    { "<leader>c", mode = { "n", "x" }, desc = "Pi review comment" },
    { "<leader>C", mode = "n", desc = "Pi review file comment" },
    { "<leader>l", mode = "n", desc = "Pi review list" },
  },
  config = function(_, opts)
    require("odas0r.features.pi_review").setup(opts)
  end,
}
