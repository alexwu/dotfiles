---
paths:
  - "dot_aerospace.toml"
  - "dot_config/borders/**"
  - "dot_config/sketchybar/**"
  - "dot_hammerspoon/**"
  - "dot_config/yazi/**"
---

# Desktop

## AeroSpace (tiling WM)
- Config: `dot_aerospace.toml` — tiling window manager for macOS
- Starts at login, uses vim-style navigation (alt+hjkl for focus, alt+shift+hjkl for move)
- Workspace assignments: 0=Slack (built-in monitor), 1=Main (Btty, WezTerm, Arc, Dia, Figma), 2=Not-work browser (Helium; the old Notes rules for Things, Notion, Obsidian still point here), 3=Dev (Ghostty, Warp, Zen, Xcode), 4=Chat/Email, 5=AI (Claude, ChatGPT), 6=Remote (Parsec, Screens 5, Moonlight)
- `config-version = 2`: persistent workspaces are listed explicitly in `persistent-workspaces` (0–6 and the two scratchpads); 7 and 8 exist only while occupied
- Scratch apps are run by `aerospace-manager` (`~/Code/aerospace-manager`; agent in `~/Applications`, CLI at `~/.local/bin/aerospace-manager`). `dot_config/aerospace-manager/scratch.json` lists them: `dashboard` (kitty), `term` (Ghostty), `zed`, `neovide`, each with how to match the app and what to launch when it has no window. `alt-d`, `alt-shift-d`, `alt-z`, `alt-n` call `aerospace-manager scratch toggle <name>`. Adding a scratch app is one entry there and one binding here; the sizer's app list in `scratch.lua` and the borders blacklist are still separate
- The manager's agent floats a listed app's new windows itself, so `dot_aerospace.toml` has no float rules for them. Hidden windows live on `.scratchpad.1` (built-in) and `.scratchpad.2` (main monitor) and show as a tray of icon pills at the end of that monitor's pill bar; a click brings one back. Floating windows of apps that aren't listed are never touched
- `aerospace-manager scratch mark <name>` pins a name to the focused window, so `mark zed` makes `alt-z` toggle that one Zed window; `unmark` or closing the window frees it. Marks live in the agent's memory and don't survive its restart
- Neovide is a bare mise binary with no bundle id; its entry matches app name `neovide`, and its tray pill has no icon
- When something outside AeroSpace focuses a hidden scratch window, AeroSpace switches to its `.scratchpad` workspace and the agent moves the window to the workspace you were on. Quitting an app can hand focus to a hidden scratch window and trigger this
- Bindings call the CLI by full path (`$HOME/.local/bin/aerospace-manager`): AeroSpace's exec PATH has Homebrew prepended and is not known to include `~/.local/bin`
- `alt-g` goes home: `aerospace-manager arrange home` runs `run-callback --for-every-window on-window-detected`, which re-sorts every open window by the rules (it also undoes any deliberate move, e.g. Helium parked on 1)
- `alt-t` runs `aerospace-manager arrange tidy`: it tidies the focused workspace (flatten + balance), and on an already-flat workspace cycles the root layout columns → rows → stack. AeroSpace's own `layout a b c` can't cycle; it only flips between two. `arrange columns|rows|stack|main-stack` are unbound presets; `main-stack` puts the focused window on the left and the rest in a column
- `aerospace-scratchpad` (Homebrew tap `cristianoliveira/tap`) and the global justfile recipe `arrange` are still installed and no longer bound to anything
- Service mode: `alt+shift+;`, join mode: `alt+shift+/`
- Floating exceptions: System Preferences, CleanShot, Chromium, Fantastical, Wispr Flow, Aqua Voice

## JankyBorders
- Config: `dot_config/borders/executable_bordersrc`
- Round style, width 6.0, active color: glow white, inactive: dim gray
- Blacklist: iPhone Mirroring, Dropover, the scratchpad apps (`ghostty`, `kitty`, `zed`, `neovide`), and the apps AeroSpace always floats (`System Settings`, `CleanShot X`, `Fantastical`). The blacklist is an exact, case-sensitive match on the process name (`proc_name`), which is the executable name and not the app's display name: `Ghostty` does nothing, `ghostty` works. It filters whole apps only; borders has no per-window or floating-window filter (upstream requests #57 and #73 are open)

## Sketchybar
- Config: `dot_config/sketchybar/` — Lua-based config (`init.lua`, `bar.lua`, `default.lua`)
- Has AeroSpace workspace plugin at `plugins/executable_aerospace.sh`

## Hammerspoon
- Config: `dot_hammerspoon/` — contains `init.lua` and AeroSpace overview script
- `knock.lua` watches the screen lock (`hs.caffeinate.watcher`) and posts `away` on lock and `back` on unlock to every socket in `/tmp/cc-knock/`, one per Claude Code session running the knock mod. The session counts what finishes while the screen is locked and, on unlock, offers a "what did I miss" question in its prompt box.
- `knock.lua` calls `/opt/homebrew/bin/xh` by full path. Hammerspoon runs with launchd's PATH, and the mise shim for `xh` has no version set, so the shim only works where it can fall through to Homebrew's `xh` on the PATH. Called by its own path from Hammerspoon it exits 1 with "No version is set for shim: xh".
- `hs -c` hangs when run from a pueue task; run it from a shell.
- `scratch.lua` sizes a new Ghostty, kitty, Zed or Neovide window once, when it is created: centered on its screen at 70% × 75% of the usable area, with the width capped at 1.6 × the height so it stays a normal window on the ultrawide. AeroSpace and `aerospace-scratchpad` can't place floating windows. Windows that already exist, and ones moved by hand later, are left alone.

## Yazi
- Config: `dot_config/yazi/yazi.toml`
- `show_hidden = true`
- Git status fetcher prepended for all files/dirs
- Shell wrapper `y()` in zshrc tracks cwd changes
