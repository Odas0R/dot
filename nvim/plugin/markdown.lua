local autocmd = vim.api.nvim_create_autocmd

-- vim-markdown settings

-- vim.g.vim_markdown_folding_disabled = 1
-- vim.g.vim_markdown_conceal_code_blocks = 1
-- vim.g.vim_markdown_new_list_item_indent = 2
-- vim.g.vim_markdown_no_extensions_in_markdown = 0
-- vim.g.vim_markdown_autowrite = 1
-- vim.g.vim_markdown_edit_url_in = "current"
-- vim.g.vim_markdown_conceal = 2

autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.tw = 79
    vim.opt_local.foldlevel = 99
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})
