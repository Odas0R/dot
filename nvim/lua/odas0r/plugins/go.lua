return {
	"ray-x/go.nvim",
	dependencies = { -- optional packages
		"neovim/nvim-lspconfig",
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("go").setup({
			lsp_inlay_hints = {
				enable = false,
			},
		})
	end,
	event = { "CmdlineEnter" },
	ft = { "go", "gomod" },
}
