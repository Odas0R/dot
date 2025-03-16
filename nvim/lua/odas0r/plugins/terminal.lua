local Util = require("odas0r.utils")

return {
	"odas0r/terminal.nvim",
	dir = "~/github.com/odas0r/dot/nvim/lua/odas0r/internal/terminal",
	opts = {},
	config = function(_, opts)
		require("odas0r.internal.terminal").setup(opts)
	end,
	keys = {
		{
			"<leader>t",
			function()
				require("odas0r.internal.terminal").toggle()
			end,
			mode = { "n", "t" },
			desc = "Toggle terminal",
		},
		{
			"<Esc>",
			"<C-\\><C-n>",
			mode = "t",
			desc = "Exit terminal mode",
		},
		{
			"<C-v><Esc>",
			"<Esc>",
			mode = "t",
			desc = "Send Escape to terminal",
		},
	},

	init = function()
		Util.autocmd("BufReadPre", {
			pattern = "*",
			group = Util.augroup("terminal"),
			callback = function()
				vim.cmd([[
    lua terminal:close()
  ]])
			end,
		})
		Util.autocmd("BufWinEnter", {
			pattern = "*",
			group = Util.augroup("terminal"),
			callback = function()
				vim.cmd([[
    lua terminal:close()
  ]])
			end,
		})
		Util.autocmd("TermOpen", {
			pattern = "*",
			group = Util.augroup("terminal"),
			callback = function()
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
				vim.opt_local.cursorline = false
			end,
		})
		Util.autocmd("TermLeave", {
			pattern = "*",
			group = Util.augroup("terminal"),
			callback = function()
				vim.cmd([[
					stopinsert
				]])
			end,
		})
		Util.autocmd("TermClose", {
			pattern = "*",
			group = Util.augroup("terminal"),
			callback = function()
				vim.cmd([[
					if (expand('<afile>') !~ "fzf") && (expand('<afile>') !~ "ranger") && (expand('<afile>') !~ "coc") |
						call nvim_input('<CR>')  |
					endif
				]])
			end,
		})
	end,
}
