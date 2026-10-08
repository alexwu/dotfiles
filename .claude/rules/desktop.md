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
- Workspace assignments: 0=Slack (built-in monitor), 1=Main (WezTerm, Arc, Dia, Figma), 2=Notes (Things, Notion, Obsidian), 3=Dev (Ghostty, Warp, Zen, Xcode), 4=Chat/Email, 5=Remote (Parsec, Moonlight)
- `exec-on-workspace-change` triggers a Raycast extension for workspace display
- Service mode: `alt+shift+;`, join mode: `alt+shift+/`
- Floating exceptions: System Preferences, CleanShot, Chromium, Fantastical, Wispr Flow, Aqua Voice

## JankyBorders
- Config: `dot_config/borders/executable_bordersrc`
- Round style, width 6.0, active color: glow white, inactive: dim gray
- Blacklist: iPhone Mirroring, Dropover

## Sketchybar
- Config: `dot_config/sketchybar/` — Lua-based config (`init.lua`, `bar.lua`, `default.lua`)
- Has AeroSpace workspace plugin at `plugins/executable_aerospace.sh`

## Hammerspoon
- Config: `dot_hammerspoon/` — contains `init.lua` and AeroSpace overview script
- `knock.lua` watches the screen lock (`hs.caffeinate.watcher`) and posts `away` on lock and `back` on unlock to every socket in `/tmp/cc-knock/`, one per Claude Code session running the knock mod. The session counts what finishes while the screen is locked and, on unlock, offers a "what did I miss" question in its prompt box.
- It calls `/opt/homebrew/bin/xh` by full path. Hammerspoon runs with launchd's PATH, and the mise shim for `xh` has no version set, so the shim only works where it can fall through to Homebrew's `xh` on the PATH. Called by its own path from Hammerspoon it exits 1 with "No version is set for shim: xh".
- `hs -c` hangs when run from a pueue task; run it from a shell.

## Yazi
- Config: `dot_config/yazi/yazi.toml`
- `show_hidden = true`
- Git status fetcher prepended for all files/dirs
- Shell wrapper `y()` in zshrc tracks cwd changes
