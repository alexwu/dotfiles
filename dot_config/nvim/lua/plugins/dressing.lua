require("dressing").setup({
	input = {
		enabled = true,
	},
	select = {
		enabled = true,

		-- Priority list of preferred vim.select implementations
		backend = { "telescope", "nui" },

		telescope = require("telescope.themes").get_dropdown(),

		-- Options for nui Menu
		nui = {
			position = "50%",
			size = nil,
			relative = "editor",
			border = {
				style = "rounded",
			},
			max_width = 120,
			max_height = 80,
		},

		-- Options for built-in selector
		builtin = {
			-- These are passed to nvim_open_win
			anchor = "NW",
			relative = "cursor",
			border = "rounded",

			-- Window transparency (0-100)
			winblend = 10,
			-- Change default highlight groups (see :help winhl)
			winhighlight = "",

			-- These can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
			width = nil,
			max_width = 0.8,
			min_width = 40,
			height = nil,
			max_height = 0.9,
			min_height = 10,
		},
	},
})