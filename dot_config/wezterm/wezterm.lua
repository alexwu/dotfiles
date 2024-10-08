local wezterm = require("wezterm")
-- local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
local act = wezterm.action

---@class WeztermConfig
local config = {}
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

---@param resize_or_move '"resize"'|'"move"'
---@param key string
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

wezterm.on("update-right-status", function(window, _)
	window:set_right_status(wezterm.format({
		{ Attribute = { Intensity = "Bold" } },
		{ Text = window:mux_window():get_workspace():gsub("^.*/", "") .. " " },
		"ResetAttributes",
	}))
end)

-- wezterm.on("window-focus-changed", function(window, pane)
-- 	window:toast_notification(
-- 		"wezterm",
-- 		"the focus state of " .. window:window_id() .. " changed to " .. tostring(window:is_focused()),
-- 		nil,
-- 		4000
-- 	)
-- 	-- window:toast_notification("wezterm", "the focus state of ", window:window_id(), " changed to ", window:is_focused(), nil, 4000)
-- 	wezterm.log_info("the focus state of ", window:window_id(), " changed to ", tostring(window:is_focused()))
-- end)
--
-- wezterm.on("window-config-reloaded", function(window, pane)
-- 	window:toast_notification("wezterm", "configuration reloaded!", nil, 4000)
-- end)

wezterm.on("user-var-changed", function(window, pane, name, value)
	if name == "switch-workspace" then
		local cmd_context = wezterm.json_parse(value)
		window:perform_action(
			act.SwitchToWorkspace({
				name = cmd_context.workspace,
				spawn = {
					cwd = cmd_context.cwd,
				},
			}),
			pane
		)
	end
end)

config.color_scheme = "Snazzy"
-- config.color_scheme = "Sonokai (Gogh)"
-- config.color_scheme = "Snazzy (base16)"
-- config.color_scheme = "Dracula (Gogh)"
-- config.color_scheme = "Dracula (Official)"

config.font = wezterm.font_with_fallback({
	{ family = "SF Mono", weight = 450 },
	{ family = "Fira Code", weight = 450 },
	"codicon",
	{ family = "FiraCode Nerd Font", weight = 450 },
})

config.font_rules = {
	{
		italic = true,
		font = wezterm.font("Victor Mono", { style = "Italic" }),
	},
}

config.keys = {
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action({
			SplitPane = {
				direction = "Right",
				size = { Percent = 33 },
				-- top_level = true,
			},
		}),
	},
	{
		key = "s",
		mods = "CMD",
		action = wezterm.action({
			SplitPane = {
				direction = "Down",
				size = { Percent = 33 },
			},
		}),
	},
	{
		key = "`",
		mods = "CTRL",
		action = wezterm.action({
			SplitPane = {
				direction = "Down",
				size = { Percent = 33 },
			},
		}),
	},
	{ key = "w", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
	{
		key = "P",
		mods = "CTRL|SHIFT",
		action = wezterm.action.DisableDefaultAssignment,
	},
	-- {
	-- 	key = "P",
	-- 	mods = "CMD",
	-- 	action = wezterm.action.DisableDefaultAssignment,
	-- },
	{
		key = "m",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "N",
		mods = "CMD|SHIFT",
		action = act.PromptInputLine({
			description = wezterm.format({
				{ Attribute = { Intensity = "Bold" } },
				{ Foreground = { AnsiColor = "Fuchsia" } },
				{ Text = "Enter name for new workspace" },
			}),
			action = wezterm.action_callback(function(window, pane, line)
				-- line will be `nil` if they hit escape without entering anything
				-- An empty string if they just hit enter
				-- Or the actual line of text they wrote
				if line then
					window:perform_action(
						act.SwitchToWorkspace({
							name = line,
						}),
						pane
					)
				end
			end),
		}),
	},
	{
		key = "P",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivateCommandPalette,
	},
	{
		key = "k",
		mods = "CMD",
		action = wezterm.action.ActivateCommandPalette,
	},
	{
		key = "=",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "-",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "0",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},
-- {
	-- 	key = "p",
	-- 	mods = "CMD",
	-- 	action = workspace_switcher.switch_workspace(),
	-- },
	split_nav("move", "h"),
	split_nav("move", "j"),
	split_nav("move", "k"),
	split_nav("move", "l"),
	-- split_nav("resize", "h"),
	-- split_nav("resize", "j"),
	-- split_nav("resize", "k"),
	-- split_nav("resize", "l"),
}

config.window_close_confirmation = "NeverPrompt"
config.unix_domains = {
	{
		name = "unix",
	},
}

config.enable_kitty_keyboard = true
config.enable_csi_u_key_encoding = false
-- workspace_switcher.apply_to_config(config)

-- config.window_background_opacity = 0.9
-- config.macos_window_background_blur = 20

-- This causes `wezterm` to act as though it was started as
-- `wezterm connect unix` by default, connecting to the unix
-- domain on startup.
-- If you prefer to connect manually, leave out this line.
-- config.default_gui_startup_args = { "connect", "unix" }

-- config.default_prog = { "/opt/homebrew/bin/nu" }

config.font_size = 14.0

return config
