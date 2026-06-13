return {
  "MaxDillon/render-markdown.nvim",
  branch = "feat/table-cell-wrapping",
  name = "render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    preset = "obsidian",
    link = {
      wiki = { enabled = false },
    },
  },
}
