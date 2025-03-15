local Utils = require("odas0r.utils")

local closeTerminal = function()
	if terminal == nil then
		return
	end
	vim.cmd([[
    lua terminal:close()
  ]])
end

return {
	"ThePrimeagen/harpoon",
	init = function()
		-----------------------------------
		-- Keymaps
		-----------------------------------
		Utils.map("n", "<leader>a", function()
			require("harpoon.mark").add_file()
		end)
		Utils.map("n", "<C-e>", function()
			require("harpoon.ui").toggle_quick_menu()
		end)

		Utils.map({ "n", "t" }, "<leader>1", function()
			closeTerminal()
			require("harpoon.ui").nav_file(1)
		end)

		Utils.map({ "n", "t" }, "<leader>2", function()
			closeTerminal()
			require("harpoon.ui").nav_file(2)
		end)

		Utils.map({ "n", "t" }, "<leader>3", function()
			closeTerminal()
			require("harpoon.ui").nav_file(3)
		end)

		Utils.map({ "n", "t" }, "<leader>4", function()
			closeTerminal()
			require("harpoon.ui").nav_file(4)
		end)

		-----------------------------------
		-- Augroups
		-----------------------------------
		Utils.autocmd("FileType", {
			pattern = "harpoon",
			group = Utils.augroup("harpoon"),
			callback = function()
				vim.opt_local.cursorline = true
			end,
		})
	end,
	config = function()
		require("harpoon").setup({
			global_settings = {
				enter_on_sendcmd = true,
			},
		})
	end,
}
