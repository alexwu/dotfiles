local wezterm = require("wezterm")

return {
	color_scheme = "Snazzy",
	font = wezterm.font("Fira Code", { weight = 450, stretch = "Normal", italic = false }),
	font_size = 14,
	window_background_opacity = 1.0,
	window_frame = {
		font = wezterm.font("Fira Code", { weight = 450, stretch = "Normal", italic = false }),

		-- The size of the font in the tab bar.
		-- Default to 10. on Windows but 12.0 on other systems
		font_size = 14.0,

		-- The overall background color of the tab bar when
		-- the window is focused
		active_titlebar_bg = "#282a36",

		-- The overall background color of the tab bar when
		-- the window is not focused
		inactive_titlebar_bg = "#282a36",

		-- The color of the inactive tab bar edge/divider
		inactive_tab_edge = "#282a36",
	},
}
