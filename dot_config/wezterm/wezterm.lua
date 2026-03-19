local wezterm = require("wezterm")
local act = wezterm.action

local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

local sessionizer = wezterm.plugin.require("https://github.com/mikkasendke/sessionizer.wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
local smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local toggle_terminal = wezterm.plugin.require("https://github.com/zsh-sage/toggle_terminal.wez")

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

smart_splits.apply_to_config(config, {
	-- the default config is here, if you'd like to use the default keys,
	-- you can omit this configuration table parameter and just use
	-- smart_splits.apply_to_config(config)

	-- directional keys to use in order of: left, down, up, right
	-- direction_keys = { "h", "j", "k", "l" },
	-- if you want to use separate direction keys for move vs. resize, you
	-- can also do this:
	direction_keys = {
		move = { "h", "j", "k", "l" },
		resize = { "LeftArrow", "DownArrow", "UpArrow", "RightArrow" },
	},
	-- modifier keys to combine with direction_keys
	modifiers = {
		move = "CTRL", -- modifier to use for pane movement, e.g. CTRL+h to move left
		resize = "META", -- modifier to use for pane resize, e.g. META+h to resize to the left
	},
	-- log level to use: info, warn, error
	log_level = "info",
})

wezterm.on("update-right-status", function(window, _)
	local workspaces = wezterm.mux.get_workspace_names()

	local cells = {}
	for _i, name in ipairs(workspaces) do
		if name == wezterm.mux.get_active_workspace() then
			table.insert(cells, { Foreground = { Color = "#1D1F29" } })
			table.insert(cells, { Attribute = { Intensity = "Bold" } })
			table.insert(cells, { Background = { Color = "#5af78e" } })
			table.insert(cells, { Text = " " .. name .. " " })
			table.insert(cells, "ResetAttributes")
		else
			table.insert(cells, { Text = " " .. name .. " " })
		end
	end

	window:set_right_status(wezterm.format(cells))
end)

wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, workspace)
	local gui_win = window:gui_window()
	local base_path = string.gsub(workspace, "(.*[/\\])(.*)", "%2")
	gui_win:set_right_status(wezterm.format({
		{ Foreground = { Color = "green" } },
		{ Text = base_path .. "  " },
	}))
end)

wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, workspace)
	local gui_win = window:gui_window()
	local base_path = string.gsub(workspace, "(.*[/\\])(.*)", "%2")
	gui_win:set_right_status(wezterm.format({
		{ Foreground = { Color = "green" } },
		{ Text = base_path .. "  " },
	}))
end)

wezterm.on("augment-command-palette", function(window, pane)
	return {
		{
			brief = "Rename tab",
			icon = "md_rename_box",

			action = act.PromptInputLine({
				description = "Enter new name for tab",
				initial_value = window:active_tab():get_title(),
				action = wezterm.action_callback(function(window, pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		{
			brief = "Rename workspace",
			icon = "md_rename_box",

			action = act.PromptInputLine({
				description = "Enter new name for workspace",
				initial_value = wezterm.mux.get_active_workspace(),
				action = wezterm.action_callback(function(window, pane, line)
					if line then
						wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
					end
				end),
			}),
		},
		{
			brief = "Switch workspace",
			icon = "",

			action = workspace_switcher.switch_workspace(),
		},
		{
			brief = "Save workspace",
			icon = "",
			action = wezterm.action_callback(function(win, pane)
				resurrect.save_state(resurrect.workspace_state.get_workspace_state())
				resurrect.window_state.save_window_action()
			end),
		},

		{
			brief = "Restore workspace",
			icon = "",
			action = wezterm.action_callback(function(win, pane)
				resurrect.fuzzy_load(win, pane, function(id, label)
					local type = string.match(id, "^([^/]+)") -- match before '/'
					id = string.match(id, "([^/]+)$") -- match after '/'
					id = string.match(id, "(.+)%..+$") -- remove file extension
					local opts = {
						relative = true,
						restore_text = true,
						on_pane_restore = resurrect.tab_state.default_on_pane_restore,
					}
					if type == "workspace" then
						local state = resurrect.load_state(id, "workspace")
						resurrect.workspace_state.restore_workspace(state, opts)
					elseif type == "window" then
						local state = resurrect.load_state(id, "window")
						resurrect.window_state.restore_window(pane:window(), state, opts)
					elseif type == "tab" then
						local state = resurrect.load_state(id, "tab")
						resurrect.tab_state.restore_tab(pane:tab(), state, opts)
					end
				end)
			end),
		},
	}
end)

config.command_palette_bg_color = "#23272e"
config.command_palette_fg_color = "#eff0eb"
config.command_palette_font_size = 16

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

config.font = wezterm.font_with_fallback({
	{ family = "Fira Code", weight = 450 },
	"codicon",
	-- { family = "FiraCode Nerd Font Mono", weight = 450 },
	{ family = "Maple Mono NF", weight = 450 },
	{ family = "Nerd Font Symbols Font", weight = 450 },
})

sessionizer.apply_to_config(config, true) -- disable default binds (right now you can also just not call this)
sessionizer.config = {
	paths = "/Users/jamesbombeelu/Code",
}

config.window_frame = {
	font = wezterm.font({ family = "SF Mono", weight = 450 }),
	font_size = 16.0,
	active_titlebar_bg = "#1D1F29",
	inactive_titlebar_bg = "#333333",
}

config.keys = {
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action_callback(function(win, pane)
			local tab = pane:tab()
			local panes = tab:panes_with_info()

			if #panes == 1 then
				pane:split({
					direction = "Right",
					size = 0.33,
				})
			elseif not panes[1].is_zoomed then
				panes[1].pane:activate()
				tab:set_zoomed(true)
			elseif panes[1].is_zoomed then
				tab:set_zoomed(false)
				panes[2].pane:activate()
			end
		end),
	},
	{
		key = "d",
		mods = "CMD|SHIFT",
		action = wezterm.action({
			SplitPane = {
				direction = "Down",
				size = { Percent = 50 },
				-- top_level = true,
			},
		}),
	},
	-- {
	-- 	key = "s",
	-- 	mods = "CMD",
	-- 	action = wezterm.action_callback(function(win, pane)
	-- 		local tab = pane:tab()
	-- 		local panes = tab:panes_with_info()
	--
	-- 		if #panes == 1 then
	-- 			pane:split({
	-- 				direction = "Down",
	-- 				size = 0.33,
	-- 			})
	-- 		elseif not panes[1].is_zoomed then
	-- 			panes[1].pane:activate()
	-- 			tab:set_zoomed(true)
	-- 		elseif panes[1].is_zoomed then
	-- 			tab:set_zoomed(false)
	-- 			panes[2].pane:activate()
	-- 		end
	-- 	end),
	-- },
	{
		key = "`",
		mods = "CMD",
		action = wezterm.action_callback(function(win, pane)
			local tab = pane:tab()
			local panes = tab:panes_with_info()

			if #panes == 1 then
				pane:split({
					direction = "Down",
					size = 0.33,
					top_level = true,
				})
			elseif not panes[1].is_zoomed then
				panes[1].pane:activate()
				tab:set_zoomed(true)
			elseif panes[1].is_zoomed then
				tab:set_zoomed(false)
				panes[2].pane:activate()
			end
		end),
	},
	{ key = "w", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
	{
		key = "P",
		mods = "CTRL|SHIFT",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "P",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "m",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "Enter",
		mods = "ALT",
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
		action = workspace_switcher.switch_workspace(),
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
	{
		key = "s",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "Enter",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{ key = "Enter", mods = "SHIFT", action = wezterm.action({ SendString = "\x1b\r" }) },
	{ key = ".", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(1) },
	{ key = ",", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(-1) },
	-- {
	-- 	key = "s",
	-- 	mods = "CMD|SHIFT",
	-- 	action = sessionizer.show,
	-- },
	-- {
	-- 	key = "r",
	-- 	mods = "CMD|SHIFT",
	-- 	action = sessionizer.switch_to_most_recent,
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

toggle_terminal.apply_to_config(config)

config.max_fps = 120
config.window_close_confirmation = "NeverPrompt"
config.unix_domains = {
	{
		name = "unix",
	},
}
-- config.enable_kitty_keyboard = true
-- config.enable_csi_u_key_encoding = false
config.window_background_opacity = 0.9
config.macos_window_background_blur = 25
config.front_end = "WebGpu"
config.font_size = 14.0
config.notification_handling = "AlwaysShow"

return config
