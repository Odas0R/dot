local actions = require("telescope.actions")

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
        ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
        ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,

        ["<C-/>"] = actions.toggle_all,
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
  },
  extensions = {
    fzf = {
      fuzzy = true,
      -- case_mode = "smart_case",
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

M.search_zet_fleet = function(tags)
  if #tags == 0 then
    require("telescope.builtin").live_grep({
      prompt_title = "[Fleet]",
      cwd = "~/github.com/odas0r/zet/fleet",
      hidden = true,
    })
  end

  local search = ""

  for index, tag in ipairs(tags) do
    if index < #tags then
      search = search .. tag .. "|"
    else
      search = search .. tag
    end
  end

  -- create the regex expression
  search = "(" .. search .. ")"

  -- Search on zettel
  require("telescope.builtin").grep_string({
    search = search,
    prompt_title = "[Fleet]: " .. search,
    cwd = "~/github.com/odas0r/zet/fleet",
    use_regex = true,
    word_match = "-w",
    hidden = true,
  })
end

M.search_zet_permanent = function(tags)
  if #tags == 0 then
    require("telescope.builtin").live_grep({
      prompt_title = "[Permanent]",
      cwd = "~/github.com/odas0r/zet/permanent",
      hidden = true,
    })
  end

  local search = ""

  for index, tag in ipairs(tags) do
    if index < #tags then
      search = search .. tag .. "|"
    else
      search = search .. tag
    end
  end

  -- create the regex expression
  search = "(" .. search .. ")"

  -- Search on zettel
  require("telescope.builtin").grep_string({
    search = search,
    prompt_title = "[Permanent]: " .. search,
    cwd = "~/github.com/odas0r/zet/permanent",
    use_regex = true,
    word_match = "-w",
    hidden = true,
  })
end

return M
