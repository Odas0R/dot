return {
  -- tag = "0.1.2",
  "nvim-telescope/telescope.nvim",
  lazy = false,
  init = function()
    local Utils = require("odas0r.utils")

    Utils.map("n", "<C-p>", function()
      return require("telescope.builtin").find_files({
        prompt_title = "Query",
      })
    end)

    Utils.map("n", "<C-g>", function()
      return require("telescope.builtin").live_grep({
        prompt_title = "Query",
      })
    end)

    vim.keymap.set("n", "<leader>d", function()
      local current_dir = vim.fn.getcwd()
      return require("telescope.builtin").find_files({
        prompt_title = "Directories in " .. vim.fn.fnamemodify(current_dir, ":~"),
        cwd = current_dir,
        find_command = { "fd", "--type", "d", "--strip-cwd-prefix" },
      })
    end)

    Utils.map("n", "<leader>fp", function()
      return require("telescope.builtin").find_files({
        prompt_title = "github.com",
        cwd = os.getenv("HOME") .. "/github.com",
        follow = true,
        use_regex = false,
        hidden = true,
      })
    end)

    Utils.map("n", "<leader>fg", function()
      return require("telescope.builtin").live_grep({
        prompt_title = "github.com",
        cwd = os.getenv("HOME") .. "/github.com",
        follow = true,
        use_regex = false,
        hidden = true,
      })
    end)
  end,
  config = function()
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
          prompt_position = "top",
          horizontal = {
            preview_width = 60,
          },
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
            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,
            -- disable
            -- ["<C-u>"] = false,
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

            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,
            -- disable
            -- ["<C-u>"] = false,
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
        -- @source: https://github.com/nvim-telescope/telescope-fzf-native.nvim#telescope-setup-and-configuration
        fzf = {
          fuzzy = true, -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true, -- override the file sorter
          case_mode = "smart_case", -- or "ignore_case" or "respect_case"
        },
      },
    })

    -- To get fzf loaded and working with telescope, you need to call
    -- load_extension, somewhere after setup function:
    require("telescope").load_extension("fzf")
  end,
}
