local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local custom_actions = {}

local function getTableSize(t)
  local count = 0
  for _, _ in pairs(t) do
    count = count + 1
  end
  return count
end

function custom_actions.fzf_multi_select(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local num_selections = getTableSize(picker:get_multi_selection())

  if num_selections > 1 then
    actions.add_to_qflist(prompt_bufnr)
    actions.open_qflist(prompt_bufnr)
  else
    actions.file_edit(prompt_bufnr)
  end
end

require("telescope").load_extension("fzf")
require("telescope").setup({
  defaults = {
    layout_strategy = "horizontal",
    layout_config = {
      height = 0.95,
      width = 0.95,
      prompt_position = "bottom",
      preview_width = 0.6,
    },
    sorting_strategy = "ascending",
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-p>"] = actions.move_selection_previous,
        ["<C-n>"] = actions.move_selection_next,
        ["<tab>"] = actions.toggle_selection + actions.move_selection_next,
        ["<s-tab>"] = actions.toggle_selection + actions.move_selection_previous,
        ["<cr>"] = custom_actions.fzf_multi_select,
        ["<C-a>"] = actions.toggle_all,
        ["<C-u>"] = false
      },
      n = {
        ["<esc>"] = actions.close,
        ["<tab>"] = actions.toggle_selection + actions.move_selection_next,
        ["<s-tab>"] = actions.toggle_selection + actions.move_selection_previous,
        ["<C-p>"] = actions.move_selection_previous,
        ["<C-n>"] = actions.move_selection_next,
        ["<cr>"] = custom_actions.fzf_multi_select,
      },
    },
    file_ignore_patterns = {
      ".git",
      "node_modules",
    },
    prompt_prefix = " > ",
    selection_caret = "  ",
    color_devicons = true,
  },
  pickers = {
    find_files = {
      find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      case_mode = "smart_case",
    },
  },
})

local M = {}

M.search_repos = function()
  require("telescope.builtin").find_files({
    prompt_title = "github.com/odas0r",
    cwd = "/home/odas0r/github.com/odas0r",
    follow = true,
    use_regex = false,
    hidden = true,
  })
end


M.search_repos_grep = function()
  require("telescope.builtin").live_grep({
    prompt_title = "github.com/odas0r",
    cwd = "/home/odas0r/github.com/odas0r",
    follow = true,
    use_regex = false,
    hidden = true,
  })
end

return M
