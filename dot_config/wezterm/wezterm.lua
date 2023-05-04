local wezterm = require("wezterm")

-- -- Equivalent to POSIX basename(3)
-- -- Given "/foo/bar" returns "bar"
-- -- Given "c:\\foo\\bar" returns "bar"
-- local function basename(s)
-- 	return string.gsub(s, "(.*[/\\])(.*)", "%2")
-- end
--
-- local function is_vim(pane)
-- 	local process_name = basename(pane:get_foreground_process_name())
-- 	return process_name == "nvim" or process_name == "vim"
-- end
--
-- local direction_keys = {
-- 	Left = "h",
-- 	Down = "j",
-- 	Up = "k",
-- 	Right = "l",
-- 	-- reverse lookup
-- 	h = "Left",
-- 	j = "Down",
-- 	k = "Up",
-- 	l = "Right",
-- }
--
-- local function split_nav(resize_or_move, key)
-- 	return {
-- 		key = key,
-- 		mods = resize_or_move == "resize" and "META" or "CTRL",
-- 		action = w.action_callback(function(win, pane)
-- 			if is_vim(pane) then
-- 				-- pass the keys through to vim/nvim
-- 				win:perform_action({
-- 					SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
-- 				}, pane)
-- 			else
-- 				if resize_or_move == "resize" then
-- 					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
-- 				else
-- 					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
-- 				end
-- 			end
-- 		end),
-- 	}
-- end
--
return {
	color_scheme = "Snazzy",
	font = wezterm.font_with_fallback({
		-- { family = "Victor Mono", style = "Italic" },
		{ family = "Fira Code" },
		{ family = "codicons" },
	}),
	font_rules = {
		{
			italic = true,
			font = wezterm.font_with_fallback({ { family = "Victor Mono", style = "Italic" }, "codicons" }),
		},
	},
	-- font_size = 14,
	keys = {
		{
			key = "d",
			mods = "CMD",
			action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
		},
		{ key = "w", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
		-- 	-- move between split panes
		-- 	-- split_nav("move", "h"),
		-- 	-- split_nav("move", "j"),
		-- 	-- split_nav("move", "k"),
		-- 	-- split_nav("move", "l"),
		-- 	-- -- resize panes
		-- 	-- split_nav("resize", "h"),
		-- 	-- split_nav("resize", "j"),
		-- 	-- split_nav("resize", "k"),
		-- 	-- split_nav("resize", "l"),
	},
	window_background_opacity = 0.90,
	-- window_frame = {
	-- 	font = wezterm.font_with_fallback({
	-- 		{ family = "Fira Code", weight = 450, stretch = "Normal", italic = false },
	-- 		"codicons",
	-- 	}),
	font_size = 14.0,
	-- 	-- The overall background color of the tab bar when
	-- 	-- the window is focused
	-- 	active_titlebar_bg = "#282a36",
	-- 	-- The overall background color of the tab bar when
	-- 	-- the window is not focused
	-- 	inactive_titlebar_bg = "#282a36",
	-- },
	-- colors = {
	-- 	tab_bar = {
	-- 		inactive_tab_edge = "#282a36",
	-- 	},
	-- },
	-- unix_domains = {
	-- 	{
	-- 		name = "default",
	-- 	},
	-- },
	--
	-- default_gui_startup_args = { "connect", "default" },
	-- debug_key_events = true,
}
