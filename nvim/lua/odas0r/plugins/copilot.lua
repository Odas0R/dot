return {
	"zbirenbaum/copilot.lua",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = true,
				auto_trigger = true,
				hide_during_completion = true,
				debounce = 50,
				keymap = {
					accept = "<C-e>",
					accept_word = false,
					accept_line = false,
					next = "<leader>j",
					prev = "<leader>k",
					dismiss = "<C-c>",
				},
			},
			filetypes = {
				["*"] = true,
				sh = function()
					-- disable for .env files
					if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "^%.env.*") then
						return false
					end
					return true
				end,
			},
		})
	end,
}
