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
- `dot_local/bin/executable_zn` — `export SHELL=/opt/homebrew/bin/zsh` + `exec zmx attach --labels "owner=alex" "$(dbzname)"`. `owner=alex` marks a session a person opened from a terminal, set at creation; agent-launched sessions (`zmx run`, the review launcher) don't pass through `zn`. `zmx-ps --label owner=alex` lists them.
- **Session shells are homebrew zsh, deliberately.** Three-layer chain: wezterm copies `zmx_cmd`'s argv0 into every pane's `SHELL` env (appends duplicates; getenv takes the first), zmx's daemon spawns the login `$SHELL`, and atuin's hex pty-proxy (`exec atuin pty-proxy` in zshrc) respawns `$SHELL` via portable_pty. Bare `"zsh"` resolves through the minimal launchd PATH to Apple `/bin/zsh`, whose exec-time env is hidden from `ps eww` (KERN_PROCARGS2 — Apple platform binaries only); homebrew zsh exposes it. Hence full paths in wezterm.lua's `zmx_cmd` AND the `SHELL` export in `zn`.
- **Two distinct state axes — don't conflate them:** *session occupancy* (`active`/`idle` — the process tree holds a real workload vs only shells/atuin-proxy) is NOT a Claude agent's own *turn-status* (`busy`/`waiting`/`idle` from `claude agents --json`). A session can be `active` with no agent in it; an `idle` agent can sit in an `active` session. zmx-ps/zmx-reap report occupancy; agent-sessions shows both side by side.
- **Nim core in `scripts/zmx/`** (the migration off Bash/awk/jaq, one tool at a time; `zmx-ps`, `zmx-which`, `agent-sessions` and `mission-control` are ported, the rest follow). Sibling modules, imported by bare name: `zmx_types` (domain types with `distinct` `ZmxSessionName`/`ProcessId`/`ClaudeSessionId`/`CodexSessionId`, the enums `AssociationSource`/`AgentProvider`/`AgentKind`/`AgentStatus`, the wire types `SessionOut`/`ProcOut`/`WhichOut`/`AgentOut`, the `ZmxJson` flavor that writes absent optionals as `null`, and `ClaudeJson` for decoding other tools' output), `zmx_sessions` (`zmx list` into `ZmxSession`, `Result`-returning `listSessions`, `pinEnvironment` for `PATH`/`TMPDIR`), `proc_table` (process readers, tree walk, occupancy, `readEnvVar`), `zmx_snapshot` (`snapshot()`: every session with its tree and occupancy), `zmx_agents` (`claude agents --json` into `AgentSession`, `associate`, and `resolveAgents()`: sessions, agents and their associations in one value, the read `zmx-which`, `agent-sessions` and `mission-control` all start from), `git_head` (`branchOf`: the branch from `.git/HEAD`, following a worktree's `gitdir:` file, no `git` spawn), `codex_sessions` (`recentCodexSessions`: rollouts by mtime, line one decoded), `agent_rows` (the `AgentOut` rows, colours, `layout`, `watchArgs` and the `hark` handoff), and the cligen binaries `zmx_ps`, `zmx_which`, `agent_sessions` and `mission_control`. `run_onchange_build-scripts.sh.tmpl` builds the four from its `builds` list and hashes every module under `scripts/zmx/` once; a new module needs a hash line there. Libraries: `cligen`, `json_serialization`, `results`, `regex`, and `unittest2` for `test_zmx_core.nim`.
  - **Claude's `kind`, `status` and `state` stay strings.** Claude owns those sets, and a closed enum on the decode type would fail the whole listing on a value it adds. `kindOf` and `turnStatusOf` classify them into `AgentKind` and `AgentStatus` (each with an `Other` member) for sorting and colour, and `--json` echoes the raw string. `Option` fields decode absent and `null` alike to `none`.
  - **`--watch [SECS]` runs through `hark`.** `watchArgs` rewrites a bare `--watch` to `--watch=2` and `--watch 5` to `--watch=5` before cligen parses, which is why those two binaries use `dispatchCf` (only it takes `cmdLine`). The binary then `execv`s `hark run -e <n>s -- <itself> --within <min>`, looking in `~/.cargo/bin` when `hark` is off the pinned `PATH`, and exits 1 when there is none. `hark` prints its own `Every 2s: ...` header above each frame.
  - **`layout` sizes columns to content.** Cells carry their own SGR colour; `visibleLen` counts runes outside escapes, every column but the last pads to its widest cell, and a column empty in every row is dropped. Glyphs are `\uXXXX` constants in `agent_rows`.
  - **Process reading is native.** `proc_table` asks libproc: `PROC_PIDT_SHORTBSDINFO` for every pid's parent (it answers for root-owned processes; `PROC_PIDTBSDINFO` does not), then start time, memory and `KERN_PROCARGS2` argv only for session descendants. `ZMX_PS_SOURCE=ps` forces the `ps -axo` reader, which is also the fallback and what the stubbed tests use. 27 ms against the Bash version's 185 ms, most of which was `ps` formatting 2,600 processes.
  - **cligen gotcha:** `clCfg.longPfxOk = false` is required. With prefix matching on, `--name RE` is read as the boolean `--names`.
- Inspection/cleanup tools in `dot_local/bin/` (Bash), plus the Nim binaries `zmx-ps`, `zmx-which`, `agent-sessions` and `mission-control`:
  - `zmx-ps` — Nim binary. Every session as JSON (info + `labels: {k: v}` + descendant `procs: [{pid, etime, rss_kb, command}]` + `state: active|idle` occupancy verdict + `running: <program>`); filter flags `--name/--dir/--hosting RE`, `--label K[=V]`, `--detached/--attached`, `--active/--idle`, `--names` for xargs. The `zmx list --json` zmx doesn't have. `etime` and `rss_kb` are `null` when the kernel withholds them (a root-owned child). Siblings under one parent come in ascending pid order, which is not `ps`'s order. Labels are parsed by position: after `cwd`, `cmd`, `ended`, `exit_code` (zmx's own optional fields, in that order), every remaining field is a label; one with no `=` is skipped.
  - `zmx-agent-label set|unset <agent>` — run by Claude's `SessionStart` / `SessionEnd` hooks (`claude-settings.json`) with the hook JSON on stdin. Labels the ambient `$ZMX_SESSION` with `agent=claude claude_session=<session_id> claude_pid=<CLAUDE_PID>`. Identity only: turn state never goes in labels. `set` refuses when another live pid owns the labels (a nested `claude -p` inherits `ZMX_SESSION`). `unset` removes those three keys only, and only while `claude_session` still names the ending session, so `/clear`'s `SessionEnd` can't erase the id the following `SessionStart` wrote. It never calls `zmx clear`; foreign labels (the cleverific reviewer launcher's `role=`/`session=`) survive. Always exits 0.
  - `zmx-reap [--kill] [--all]` — kill detached sessions whose tree is idle; dry-run by default, active sessions always skipped. **Delegates occupancy + metadata entirely to `zmx-ps`** (no independent process-tree walk — it categorizes zmx-ps's JSON: detached+idle → reap, detached+active → skip, attached → skip). `--all` also lists attached sessions (dim) so it doubles as a full inventory. When zmx-ps ports to Nim, reap rides along.
  - `zmx-which [--json] [session|pid]` — Nim binary; the agent ↔ zmx association as a command. `agent-sessions` and `mission-control` get the same answer in-process from `resolveAgents()`. Per agent, first hit wins: `label` (session's `claude_session` label equals the agent's `sessionId`), `process_env` (`ZMX_SESSION` in the exec-time env), `process_tree` (pid is a descendant of the session daemon). `--json`: `{pid, kind, status, session_id, cwd, zmx_session, association_source, clients, occ}`. A crashed agent's leftover label matches no live `sessionId`, so it's ignored. It reads sessions in-process through `snapshot()` (no `zmx-ps` subprocess) and takes `ZMX_SESSION` from the env strings that follow argv in `KERN_PROCARGS2`; `ZMX_PS_SOURCE=ps` switches that to `ps eww -p`. If `zmx list` or `claude agents` fails it prints the reason on stderr, lists nothing, and exits 0. The human table goes through `gum table --print`, with a plain aligned table when `gum` is missing or rejects the rows. About 240 ms against the Bash version's 395 ms; `claude agents --json` alone is 180 ms.
  - `zmx-env <session> [rg-pattern]...` — env vars of a session's processes (patterns OR'd)
  - `agent-sessions [--within MIN] [--watch [SECS]] [--json]` — Nim binary; the agent-centric glance. `claude agents --json` is heterogeneous by kind: `interactive` (terminal sessions: `status` + pid → zmx session + occupancy) and `background` (headless tasks: `sessionId` + name + `state`, usually no pid). Interactive and Codex rows render as resumable sessions up top, waiting, then busy, then idle, newest first (each with its zmx session and occupancy or, for Codex, the first 8 characters of its `payload.id`); background agents get a dim section by name, short id and state. `--json` is the canonical per-agent array, Claude's agents in Claude's order, then Codex sessions newest first: `{source,kind,status,pid,session_id,short_id,name,cwd,branch,zmx_session,association_source,occ,idle_s,started}`. `status` is the turn status for `interactive` (default `idle`) and the task `state` otherwise (default `?`). Every agent that has a pid carries its zmx session, background ones included. `--within` bounds the Codex scan by rollout mtime (default 90; `0` matches nothing). `--json` wins over `--watch`; an unknown flag exits 2. A branch is `none` for a detached `HEAD` or an agent with no directory. About 230 ms against the Bash version's 605 ms.
  - `mission-control [--within MIN] [--watch [SECS]]` — Nim binary; the everything-alive superset, and what the zellij dashboard runs. Rows by priority, then newest, then directory: `cc` agents that have a pid (waiting 0, busy 1, the rest 3; status is Claude's `status`, never `state`), `cx` Codex sessions (2), and every zmx session hosting no listed agent (`shell` 4 when a client is attached, `detached` 5). The column after the status is the hosting zmx session; a trailing `·name` is the WezTerm workspace open on that directory, from `wezterm cli list --format json`. That call starts before the agent read and gets 400 ms from its start, because it hangs for about 2.3 s when WezTerm is closed; a miss is no tags. 415 ms with WezTerm closed (the deadline is the floor then), against the Bash version's 3.2 s; not yet timed with WezTerm answering, and its JSON shape (`cwd`, `workspace`) is taken from the Bash version, covered only by the harness stub.
- **Tracked env (zmx 0.8+).** `ZMX_TRACK_ENV` in `dot_zshenv` lists what zmx records from the attaching terminal: zmx's nine defaults restated (the variable replaces the built-in list), plus `TERM_PROGRAM`, `__CFBundleIdentifier`, `WEZTERM_PANE`, `WEZTERM_UNIX_SOCKET`, `BTTY_PANE`, `BTTY_TAB`, `BTTY_WORKSPACE`, `BTTY_SOCK`, `BTTY_DIR`. The `zmx attach` client reads it, not the daemon (`src/main.zig`, attach path), so it must be in the env of whatever runs `attach`, and a session only gains the new set at its next attach. `dot_zsh/zmx.zsh` registers `_zmx_refresh_env` with `add-zsh-hook precmd`: it evals `zmx print-env -s .` (about 4 ms) and returns the previous `$?` so p10k's status segment still sees it. Values come from the session's leader client; a second client that attaches doesn't replace them until it leads. **Boundary:** the hook updates the shell and what it starts next. A process already running keeps its exec-time env and has to query live: `zmx print-env . WEZTERM_PANE`. lulu-loadout's `lib/term_env.nim` does that for the notify hook, the statusline and `wezrun`. A terminal app launched from another terminal's shell inherits that terminal's pane id (WezTerm opened from btty tracks a live `BTTY_PANE`), so readers pick the terminal by tracked `TERM_PROGRAM`, which each terminal sets for its own panes. Fish has no hook yet.
- Tests: `just test-zmx` runs the Nim unit suite (`scripts/zmx/test_zmx_core.nim`), then `scripts/zmx/test-zmx-tools.sh`, which builds `zmx-ps`, `zmx-which`, `agent-sessions` and `mission-control` and runs them with the Bash `zmx-agent-label` under a throwaway `HOME` with stub `zmx`/`claude`/`ps`/`wezterm` and one Codex rollout fixture. The tools pin `$HOME/.local/bin` first on `PATH`, so running a source copy directly still calls the deployed siblings; the source files also lack `+x` until `chezmoi apply`, so wrap them (`exec bash <source>`) rather than symlinking.
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
