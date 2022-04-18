local wezterm = require("wezterm")

return {
	color_scheme = "Snazzy",
	font = wezterm.font_with_fallback({
		{ family = "Fira Code", weight = 450, stretch = "Normal", italic = false },
		"codicons",
	}),
	font_size = 14,
	keys = {
		{
			key = "d",
			mods = "CMD",
			action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
		},
		{ key = "w", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
	},
	window_background_opacity = 0.95,
	window_frame = {
		font = wezterm.font_with_fallback({
			{ family = "Fira Code", weight = 450, stretch = "Normal", italic = false },
			"codicons",
		}),
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
