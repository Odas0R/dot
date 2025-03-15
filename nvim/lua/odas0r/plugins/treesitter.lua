return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSUpdateSync" },
  config = function()
    require("nvim-treesitter.configs").setup({
      -- Core configurations
      highlight = {
        enable = true,
        disable = function(lang, buf)
          local max_filesize = 100 * 1024 -- 100 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end

          -- Disable for specific file types that are problematic
          local disabled_filetypes = { "dockerfile" }
          if vim.tbl_contains(disabled_filetypes, lang) then
            return true
          end

          -- Limit parsing for very large files
          local max_lines = 10000
          if vim.api.nvim_buf_line_count(buf) > max_lines then
            return true
          end
        end,
        additional_vim_regex_highlighting = false, -- Improves performance
      },

      indent = {
        enable = true, -- Keep this disabled if you don't use treesitter for indentation
      },

      -- Efficiently install parsers - only install what's needed
      auto_install = true, -- Automatically install missing parsers when entering buffer
      sync_install = false, -- Install parsers synchronously (only applied to `ensure_installed`)
      ignore_install = {}, -- List of parsers to ignore installing
    })
  end,
}
