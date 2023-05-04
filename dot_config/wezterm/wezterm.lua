local wezterm = require("wezterm")

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.color_scheme = "Snazzy"
config.font = wezterm.font_with_fallback({
	{ family = "Fira Code" },
	{ family = "codicons" },
})

config.font_rules = {
	{
		italic = true,
		font = wezterm.font_with_fallback({ { family = "Victor Mono", style = "Italic" }, "codicons" }),
	},
}

config.keys = {
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
	},
	{ key = "w", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
	{
		key = "P",
		mods = "CTRL|SHIFT",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "m",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "P",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivateCommandPalette,
	},
}

config.window_background_opacity = 0.90

config.font_size = 14.0

return config
