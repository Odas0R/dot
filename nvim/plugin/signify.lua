local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd

vim.g.signify_disable_by_default = 0

keymap({ "n", "i" }, "<leader>gj", "<Plug>(signify-next-hunk)<cmd>SignifyHunkDiff<CR>", { silent = true })
keymap({ "n", "i" }, "<leader>gk", "<Plug>(signify-prev-hunk)<cmd>SignifyHunkDiff<CR>", { silent = true })
keymap({ "n", "i" }, "<leader>gh", "<cmd>SignifyHunkDiff<CR>", { silent = true })

keymap({ "n", "i" }, "<leader>gu", "<cmd>SignifyHunkUndo<cr>", { silent = true })
keymap({ "n", "i" }, "<leader>gt", "<cmd>SignifyToggle<cr>", { silent = true })

vim.cmd([[
function! s:show_current_hunk() abort
  let h = sy#util#get_hunk_stats()
  if !empty(h)
    echo printf('[Hunk %d/%d]', h.current_hunk, h.total_hunks)
  endif
endfunction

autocmd User SignifyHunk call s:show_current_hunk()
]])

autocmd("FileType", {
  pattern = "*",
  callback = function()
    keymap({ "n", "i" }, "q", function()
      local winnr = vim.api.nvim_get_current_win()
      local win_type = vim.api.nvim_win_get_type(winnr)
      if win_type == "popup" then
        vim.api.nvim_win_close(winnr, true)
      end
    end, { silent = true })
  end,
})
