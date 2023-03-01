local autocmd = vim.api.nvim_create_autocmd

-- vim-markdown settings

vim.g.vim_markdown_folding_disabled = 1
vim.g.vim_markdown_conceal_code_blocks = 1
vim.g.vim_markdown_new_list_item_indent = 2
vim.g.vim_markdown_no_extensions_in_markdown = 0
vim.g.vim_markdown_autowrite = 1
vim.g.vim_markdown_edit_url_in = "current"
vim.g.vim_markdown_conceal = 2

autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.wo.conceallevel = 2
    vim.wo.spell = false
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.tw = 79
    vim.wo.foldlevel = 99
    vim.wo.wrap = true
    vim.wo.linebreak = true
  end,
})
