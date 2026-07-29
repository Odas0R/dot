local function review_session()
  return vim.env.PI_REVIEW_OVERLAY == "1"
    and vim.env.PI_REVIEW_ADDRESS ~= nil
    and vim.env.PI_REVIEW_ADDRESS ~= ""
    and vim.env.PI_REVIEW_TOKEN ~= nil
    and vim.env.PI_REVIEW_TOKEN ~= ""
end

return {
  "odas0r/pi-review.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/odas0r/features/pi_review",
  enabled = review_session(),
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
  config = function()
    require("odas0r.features.pi_review").setup()
  end,
}
