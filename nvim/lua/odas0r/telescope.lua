local actions = require("telescope.actions")

require("telescope").load_extension("fzf")

require("telescope").setup({
  defaults = {
    layout_strategy = "flex",
    layout_config = { height = 0.95, width = 0.95, prompt_position = "bottom" },
    sorting_strategy = "ascending",
    mappings = {
      i = {
        ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
        ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,

        ["/"] = actions.toggle_all,
      },
    },
    prompt_prefix = " > ",
    selection_caret = "  ",
    color_devicons = true,
  },
  pickers = {
    find_files = {
      hidden = true,
      follow = true,
      path_display = { truncate = 1 },
    },
    live_grep = {
      -- do not indent results
      additional_args = function()
        return { "--trim" }
      end,
      -- do not show line + columns in results
      disable_coordinates = true,
      -- shorten path
      path_display = { "shorten" },
    },
  },
  extensions = {
    fzf = {
      case_mode = "smart_case",
    },
  },
})

local M = {}

M.search_dotfiles = function()
  require("telescope.builtin").git_files({
    prompt_title = "Dotfiles",
    cwd = "~/dot",
    hidden = true,
  })
end

return M
