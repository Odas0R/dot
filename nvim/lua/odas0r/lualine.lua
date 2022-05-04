local lsp_status = require("lsp-status")
lsp_status.register_progress()

lsp_status.config({
  status_symbol = "",
  indicator_errors = "E",
  indicator_warnings = "W",
  indicator_info = "I",
  indicator_hint = "?",
  indicator_ok = "OK",
})

require("lualine").setup({
  options = { theme = "gruvbox_dark", section_separators = "", component_separators = "" },
  section_separators = {},
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = { "filename", lsp_status.status },
    lualine_x = { "encoding", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  extensions = { "quickfix", "fzf" },
})
