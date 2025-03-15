return {
	"mhinz/vim-signify",
	event = { "BufReadPre", "BufNewFile" },
	init = function()
		local Utils = require("odas0r.utils")

		vim.g.signify_disable_by_default = 0

		Utils.map({ "n", "i" }, "<leader>gj", "<Plug>(signify-next-hunk)<cmd>SignifyHunkDiff<CR>")
		Utils.map({ "n", "i" }, "<leader>gk", "<Plug>(signify-prev-hunk)<cmd>SignifyHunkDiff<CR>")
		Utils.map({ "n", "i" }, "<leader>gh", "<cmd>SignifyHunkDiff<CR>")

		Utils.map({ "n", "i" }, "<leader>gu", "<cmd>SignifyHunkUndo<cr>")
		Utils.map({ "n", "i" }, "<leader>gt", "<cmd>SignifyToggle<cr>")

		vim.cmd([[
			function! s:show_current_hunk() abort
				let h = sy#util#get_hunk_stats()
				if !empty(h)
					echo printf('[Hunk %d/%d]', h.current_hunk, h.total_hunks)
				endif
			endfunction

			augroup ConfigSignifyHunk
				autocmd!
				autocmd User SignifyHunk call s:show_current_hunk()
			augroup END
		]])
	end,
}
