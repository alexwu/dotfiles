---
paths:
  - "dot_config/ghostty/**"
  - "dot_config/wezterm/**"
  - "dot_config/kitty/**"
  - "dot_config/zellij/**"
  - "dot_config/petname-dbz/**"
---

# Terminals

## Terminal Emulators

### Ghostty
- Config: `dot_config/ghostty/config.ghostty`
- Font: Fira Code Retina + FiraCode Nerd Font Mono, size 14
- Theme: Snazzy, background opacity 0.85 with macOS glass blur
- `auto-update-channel = tip` (follows tip/nightly)
- Quick terminal: `super+backtick`

### WezTerm
- Config: `dot_config/wezterm/wezterm.lua`
- Plugins: smart_workspace_switcher (zoxide-backed), sessionizer, resurrect (workspace save/restore), smart-splits (nvim integration), toggle_terminal
- Color scheme: Snazzy, font: Fira Code weight 450 with Nerd Font fallback
- WebGpu frontend, background opacity 0.90 with macOS blur
- `cmd+d` toggles vsplit with zoom behavior, `cmd+k` switches workspace via zoxide
- `cmd+shift+n` creates new named workspace
- `cmd+shift+p` opens command palette (with rename tab/workspace, save/restore workspace)
- smart-splits: `ctrl+hjkl` for movement (passes through to nvim), `meta+arrows` for resize
- `wezterm-switch-workspace` shell function uses user-var protocol to switch workspaces from CLI

### Kitty
- Config: `dot_config/kitty/kitty.conf`
- Font: Fira Code, Nerd Font via `symbol_map`, size 14
- Remote control enabled (`allow_remote_control yes`, `listen_on unix:/tmp/mykitty`)
- Layout: splits, theme: snazzy.conf (included)
- `macos_option_as_alt yes`
- Navigation integrated with nvim via `pass_keys.py` kitten (`ctrl+hjkl`)

## zmx
- Session persistence (the keep-alive half of tmux); every wezterm window/tab/split auto-attaches to a fresh DBZ-named session via `zn` (wezterm `default_prog` → `zsh -c "zn; exec zsh -l"`)
- `dot_local/bin/executable_zn` — `export SHELL=/opt/homebrew/bin/zsh` + `exec zmx attach "$(dbzname)"`
- **Session shells are homebrew zsh, deliberately.** Three-layer chain: wezterm copies `zmx_cmd`'s argv0 into every pane's `SHELL` env (appends duplicates; getenv takes the first), zmx's daemon spawns the login `$SHELL`, and atuin's hex pty-proxy (`exec atuin pty-proxy` in zshrc) respawns `$SHELL` via portable_pty. Bare `"zsh"` resolves through the minimal launchd PATH to Apple `/bin/zsh`, whose exec-time env is hidden from `ps eww` (KERN_PROCARGS2 — Apple platform binaries only); homebrew zsh exposes it. Hence full paths in wezterm.lua's `zmx_cmd` AND the `SHELL` export in `zn`.
- **Two distinct state axes — don't conflate them:** *session occupancy* (`active`/`idle` — the process tree holds a real workload vs only shells/atuin-proxy) is NOT a Claude agent's own *turn-status* (`busy`/`waiting`/`idle` from `claude agents --json`). A session can be `active` with no agent in it; an `idle` agent can sit in an `active` session. zmx-ps/zmx-reap report occupancy; agent-sessions shows both side by side.
- Inspection/cleanup tools in `dot_local/bin/` (bash prototypes, Nim port once formats lock, sharing a core):
  - `zmx-ps` — every session as JSON (info + descendant procs + `state: active|idle` occupancy verdict + `running: <comm>`); filter flags `--name/--dir/--hosting RE`, `--detached/--attached`, `--active/--idle`, `--names` for xargs. The `zmx list --json` zmx doesn't have.
  - `zmx-reap [--kill] [--all]` — kill detached sessions whose tree is idle; dry-run by default, active sessions always skipped. **Delegates occupancy + metadata entirely to `zmx-ps`** (no independent process-tree walk — it categorizes zmx-ps's JSON: detached+idle → reap, detached+active → skip, attached → skip). `--all` also lists attached sessions (dim) so it doubles as a full inventory. When zmx-ps ports to Nim, reap rides along.
  - `zmx-which [session|pid]` — map `claude agents --json` pids → zmx sessions via `ZMX_SESSION` in their env
  - `zmx-env <session> [rg-pattern]...` — env vars of a session's processes (patterns OR'd)
  - `agent-sessions` — agent-centric glance, JSON-first internal model. `claude agents --json` is heterogeneous by kind: `interactive` (terminal sessions — status + pid → zmx shell + occupancy) and `background` (headless subagent tasks — sessionId + name + state, no pid). Interactive + codex render as resumable sessions up top (each with its zmx session/occupancy or, for codex, its `payload.id` resume uuid); background agents get a dim section by name + short id + state. `--within MIN`, `--watch [SECS]`, `--json` (canonical per-agent contract the Nim port inherits: `{source,kind,status,pid,session_id,short_id,name,cwd,branch,zmx_session,occ,idle_s,started}`). mission-control is the everything-alive superset. **Gotcha:** rows are assembled by joining fields with `\x1f` (US), NOT tab — `IFS=$'\t' read` collapses empty middle fields (tab is IFS-whitespace), which silently shifts every column on rows with null pid/status.
- Known edge: `zmx list`'s pid IS the session's root process; the tools only inspect *descendants*, so a session created as `zmx attach name <cmd>` (root = workload, no children) reads as idle
- **Footgun:** `zmx attach <other>` from INSIDE a session doesn't nest — it switches the current client (the user's pane!). Test session spawning with `wezterm cli spawn` instead

## Zellij
- Config: `dot_config/zellij/config.kdl`
- Theme: snazzy (custom defined in config)
- Default mode: **locked** — `ctrl+g` to unlock
- Meh key bindings (`ctrl+alt+shift+*`) work in both normal and locked modes for tab navigation/creation
- vim-zellij-navigator plugin for `ctrl+hjkl` passthrough to nvim
- `room.wasm` plugin: `ctrl+y` for quick session jumping
- `zsm.wasm` plugin: session manager with resurrectability (bound to `z` in session mode)
- zjstatus + zjstatus-hints plugins loaded at session start
- `pane_frames false`, `support_kitty_keyboard_protocol false`
- `ZELLIJ_SOCKET_DIR=/tmp/zellij` set in zshrc
- `zjn` alias creates new session with DBZ petname

## Petname (DBZ)
- Custom word lists: `dot_config/petname-dbz/` (adjectives + nouns, empty adverbs)
- `dbzname` alias generates Dragon Ball Z themed random names
- Used by `zjn` (zellij) and `zn` (zmx) aliases for session naming
