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
- Scratchpad apps (via `aerospace-scratchpad`, Homebrew tap `cristianoliveira/tap`): kitty, Ghostty, Zed and Neovide float on detection and toggle with `alt-d`, `alt-shift-d`, `alt-z`, `alt-n`; each binding launches the app when no window matches (kitty's launches the dashboard with `just -g launch-dashboard`). Hidden windows live on `.scratchpad.1` (built-in) and `.scratchpad.2` (main monitor). Only pattern toggles are bound, because the tool's `next` and `move --all-floating` treat every floating window as a scratchpad window
- Neovide is a bare mise binary with no bundle id; its rule matches app name `neovide`
- `exec-on-workspace-change` runs `aerospace-scratchpad hook pull-window`, which pulls a scratchpad window to the previous workspace when something outside AeroSpace focuses it
- `alt-g` goes home: `run-callback --for-every-window on-window-detected` re-sorts every open window by the rules (it also undoes any deliberate move, e.g. Helium parked on 1)
- `alt-t` runs the global justfile recipe `arrange`: it tidies the focused workspace (flatten + balance), and on an already-flat workspace cycles the root layout columns → rows → stack. AeroSpace's own `layout a b c` can't cycle; it only flips between two
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
