return {
	"dmmulroy/tsc.nvim",
	cmd = { "TSC" },
	init = function()
		require("tsc").setup({
			-- TO MAKE IT WORK FOR MONOREPOS
			-- flags = {
			--   build = true,
			-- },
		})
	end,
}
