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
    -- testing
    preview = {
      treesitter = false,
    },
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
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-n>"] = actions.move_selection_next,
        ["<C-p>"] = actions.move_selection_previous,
        ["<cr>"] = custom_actions.fzf_multi_select,
        ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
        -- disable
        ["<C-u>"] = false,
      },
      n = {
        ["l"] = actions.toggle_selection,
        ["h"] = actions.remove_selection,
        ["<C-p>"] = actions.move_selection_previous,
        ["<C-n>"] = actions.move_selection_next,
        ["<cr>"] = custom_actions.fzf_multi_select,
        ["L"] = actions.toggle_all,
        ["H"] = actions.drop_all,
        ["<esc>"] = actions.close,
        ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
        -- disable
        ["<C-u>"] = false,
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

local keymap = vim.keymap.set

keymap("n", "<leader>bl", function()
  return require("telescope.builtin").buffers()
end, { silent = true })
keymap("n", "<C-p>", function()
  return require("telescope.builtin").find_files()
end, { silent = true })
keymap("n", "<C-g>", function()
  return require("telescope.builtin").live_grep()
end, { silent = true })

keymap("n", "<leader>fe", function()
  return require("telescope.builtin").find_files({
    prompt_title = "github.com",
    cwd = "/home/odas0r/github.com",
    follow = true,
    use_regex = false,
    hidden = true,
  })
end, { silent = true })
keymap("n", "<leader>fg", function()
  return require("telescope.builtin").live_grep({
    prompt_title = "github.com",
    cwd = "/home/odas0r/github.com",
    follow = true,
    use_regex = false,
    hidden = true,
  })
end, { silent = true })
