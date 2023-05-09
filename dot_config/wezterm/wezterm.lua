local wezterm = require("wezterm")

if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- if you are *NOT* lazy-loading smart-splits.nvim (recommended)
local function is_vim(pane)
	-- this is set by the plugin, and unset on ExitPre in Neovim
	return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
	Left = "h",
	Down = "j",
	Up = "k",
	Right = "l",
	-- reverse lookup
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function split_nav(resize_or_move, key)
	return {
		key = key,
		mods = resize_or_move == "resize" and "META" or "CTRL",
		action = wezterm.action_callback(function(win, pane)
			if is_vim(pane) then
				-- pass the keys through to vim/nvim
				win:perform_action({
					SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
				}, pane)
			else
				if resize_or_move == "resize" then
					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
				else
					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
				end
			end
		end),
	}
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
	split_nav("move", "h"),
	split_nav("move", "j"),
	split_nav("move", "k"),
	split_nav("move", "l"),
	split_nav("resize", "h"),
	split_nav("resize", "j"),
	split_nav("resize", "k"),
	split_nav("resize", "l"),
}

config.window_background_opacity = 0.90
config.window_close_confirmation = "NeverPrompt"

config.font_size = 14.0

return config
