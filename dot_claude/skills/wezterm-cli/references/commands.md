# WezTerm CLI command reference

Official docs:
- https://wezterm.org/cli/cli/index.html
- https://wezterm.org/cli/cli/list.html
- https://wezterm.org/cli/cli/list-clients.html
- https://wezterm.org/cli/cli/spawn.html
- https://wezterm.org/cli/cli/split-pane.html
- https://wezterm.org/cli/cli/move-pane-to-new-tab.html
- https://wezterm.org/cli/cli/send-text.html
- https://wezterm.org/cli/cli/get-text.html
- https://wezterm.org/cli/cli/activate-pane.html
- https://wezterm.org/cli/cli/activate-pane-direction.html
- https://wezterm.org/cli/cli/get-pane-direction.html
- https://wezterm.org/cli/cli/activate-tab.html
- https://wezterm.org/cli/cli/set-tab-title.html
- https://wezterm.org/cli/cli/set-window-title.html
- https://wezterm.org/cli/cli/rename-workspace.html
- https://wezterm.org/cli/cli/adjust-pane-size.html
- https://wezterm.org/cli/cli/zoom-pane.html
- https://wezterm.org/cli/cli/kill-pane.html

Global options (before the subcommand): `--no-auto-start`, `--prefer-mux`, `--class <CLASS>`.
Also honored: env var `WEZTERM_UNIX_SOCKET=<path>` to pin a socket, `WEZTERM_PANE` as the
implicit `--pane-id` default.

## Inspect

- List windows/tabs/panes (human table): `wezterm cli list`
- List windows/tabs/panes (JSON — prefer this, stable to parse): `wezterm cli list --format json`
- List connected clients (table): `wezterm cli list-clients`
- List connected clients (JSON): `wezterm cli list-clients --format json`

`list --format json` rows carry `window_id`, `tab_id`, `pane_id`, `workspace`, `title` (the pane's
OSC-driven title), `tab_title` (empty `""` unless explicitly set via `set-tab-title` — `wezrun`
matches its `claude-run` pane on this), `cwd` (a `file://<host>/<abs-path>` URL), `size`,
`is_active`, `is_zoomed`, `tty_name`, `window_title` — capture the IDs you need from here before
mutating.

## Create

- Spawn a new tab in the current window (prints the new pane id): `wezterm cli spawn`
- Spawn into a specific window: `wezterm cli spawn --window-id 0`
- Spawn a brand-new window, optionally in a named workspace: `wezterm cli spawn --new-window --workspace my-workspace`
- Spawn with a working directory: `wezterm cli spawn --cwd /path/to/repo`
- Spawn running a program directly instead of the shell: `wezterm cli spawn -- bash -lc 'just test'`
  (the pane closes when the program exits — keep it open with `... -- bash -lc 'just test; exec bash'`)
- Split an existing pane (prints the new pane id): `wezterm cli split-pane --pane-id 3`
- Split direction: `--left` | `--right` (alias `--horizontal`) | `--top` | `--bottom` (default `--bottom`); `--top-level` splits the whole window instead of the active pane
- Split size: `--percent 30` (percent of available space) or `--cells 40`
- Split with a cwd: `wezterm cli split-pane --right --cwd /path/to/repo`
- Move an existing pane into a fresh tab: `wezterm cli move-pane-to-new-tab --pane-id 3`

## Focus / activate

- Focus a pane by id: `wezterm cli activate-pane --pane-id 3`
- Focus the pane in a direction (`Up` | `Down` | `Left` | `Right` | `Next` | `Prev`): `wezterm cli activate-pane-direction Right`
- Find the neighbor in a direction *without* changing focus: `wezterm cli get-pane-direction Right`
- Activate a tab by id: `wezterm cli activate-tab --tab-id 2` (also `--tab-index N` / `--no-wrap` for relative moves)

## Titles and workspaces

- Set a tab title (by tab or by any pane in it): `wezterm cli set-tab-title --tab-id 2 "api"` / `wezterm cli set-tab-title --pane-id 3 "api"`
- Set a window title: `wezterm cli set-window-title --window-id 1 "My Project"`
- Rename a workspace: `wezterm cli rename-workspace --workspace old new` (omit `--workspace` to rename the active one)

## Interact

- Send text as a paste to the current pane: `wezterm cli send-text "echo hello"`
- Send text to a specific pane: `wezterm cli send-text --pane-id 3 "echo hello"`
- **Newlines:** a literal `\n` inside a quoted arg is sent as backslash-n, *not* a newline. To
  actually run the command, feed it via stdin (`printf 'echo hello\n' | wezterm cli send-text --pane-id 3 --no-paste`)
  or use ANSI-C quoting (`wezterm cli send-text --pane-id 3 --no-paste $'echo hello\n'`).
- `--no-paste` sends the text directly rather than as a bracketed paste. Pair it with the real-newline
  forms above when the intent is to *run* the command: under bracketed paste the shell buffers the
  paste and a trailing newline doesn't reliably submit; `--no-paste` types it, so `\n` = Enter. (This
  is what `wezrun exec` does internally.)
- Read a pane's text: `wezterm cli get-text --pane-id 3`
  - `--start-line N` / `--end-line N` — line 0 is the top of the visible screen; negative numbers
    go back into scrollback. Default range is the visible viewport only, so for long output use
    e.g. `--start-line -500`.
  - `--escapes` — include ANSI color/style escape sequences (omit for clean plain text).

## Layout adjustments

- Resize a pane: `wezterm cli adjust-pane-size --pane-id 3 Right --amount 5` (direction `Up`/`Down`/`Left`/`Right`, `--amount` in cells)
- Zoom / unzoom / toggle a pane: `wezterm cli zoom-pane --pane-id 3 --toggle` (also `--zoom` / `--unzoom`)

## Destructive

- Kill a pane immediately, no confirmation: `wezterm cli kill-pane --pane-id 3`
  - **Without `--pane-id` it kills the current pane** (`$WEZTERM_PANE` / focused pane) — that's
    the agent's own shell when Claude Code runs inside WezTerm. Always pass `--pane-id`.
  - Closing the last pane of a tab closes the tab; closing the last pane of a window closes the window.
  - A standing PreToolUse Bash hook — `wezterm-guard` (`~/.local/bin/wezterm-guard`, source
    `scripts/claude/wezterm_guard.nim`) — forces a `permissionDecision: "ask"` on any
    `wezterm cli kill-*` invocation. It runs regardless of whether this skill is loaded; the
    confirmation prompt is expected, not a failure. Only proceed if closing the pane is what the
    user asked for.
