---
name: wezterm-cli
description: Drive a running WezTerm GUI/mux session from the shell via `wezterm cli` — list windows/tabs/panes, spawn tabs/windows, split panes, focus/activate panes or tabs, set tab/window titles, rename workspaces, resize/zoom panes, send text to a pane, and capture a pane's scrollback. Use whenever the user wants to automate or rearrange a WezTerm layout, manage tabs/panes/workspaces, run a command in a specific WezTerm pane, or have a long-running command (test suite, specs, build, dev server) run in a pane that both the user and the agent can watch. Triggers on "wezterm cli", "split a pane", "spawn a tab/window", "set the tab title", "rename workspace", "send text to pane", "list panes", "focus pane", "run my tests in a wezterm pane", "show X in a terminal pane so we can both see it", or any request to script a terminal layout in WezTerm specifically (not tmux/zellij/screen).
---

# WezTerm CLI

`wezterm cli` talks to a running WezTerm GUI instance (or background mux server) over its control socket. It can inspect and mutate the live session: spawn tabs/windows, split panes, move focus, label things, send keystrokes/paste, and read a pane's text back out.

If `wezterm` isn't installed, point the user at `brew install --cask wezterm` (macOS) or https://wezterm.org/install/.

> Portability note: this skill body is plain markdown. To reuse it under Codex / Cursor / Aider, copy the body and references into the host agent's rules format and rewrite the frontmatter — but note the `wezrun` shortcuts below are *this machine only* (it's a local Nim helper, source `scripts/wezterm/wezrun.nim` in the chezmoi repo, binary `~/.local/bin/wezrun`). The raw `wezterm cli` sequences — kept as labelled fallbacks throughout `references/recipes.md` — are what ports.

## Safety and invariants

- **`send-text` is remote keyboard telekinesis.** It pastes/types into a real shell. Send *exactly* what the user asked for, and include a trailing newline only when running the command is the explicit intent. Never improvise extra commands.
- **`kill-pane` destroys a pane immediately, no prompt.** Without `--pane-id` it kills the *current* pane — which is this agent's own shell if Claude Code is running inside WezTerm. Only run it when closing a pane is exactly what was requested. A standing PreToolUse hook (`wezterm-guard`, see `references/commands.md`) forces a confirmation on `wezterm cli kill-*` regardless of whether this skill is loaded — expect that prompt; it is not an error.
- **Target by ID, not by focus.** `--pane-id` / `--tab-id` / `--window-id` are deterministic. Relying on "whichever pane is focused" breaks the moment the user clicks elsewhere. Capture IDs from `wezterm cli list --format json` first, then operate on them.

## Connecting to the right instance

When multiple WezTerm GUI processes or a mux server coexist, disambiguate with one of:
- `--prefer-mux` — talk to the background mux server rather than a GUI
- `WEZTERM_UNIX_SOCKET=<path>` — pin a specific socket
- `--class <CLASS>` — target a GUI started with `wezterm gui --class <CLASS>`

For `--pane-id`-less subcommands, WezTerm uses `$WEZTERM_PANE` if set, otherwise the focused pane of the most-recently-active client. Running *inside* the intended pane → omitting `--pane-id` is usually fine. Running *outside* WezTerm, or needing precision → always pass IDs.

## Standard workflow

1. **Preflight.** `command -v wezterm`; then `wezterm cli list --format json`. If `list` fails, the GUI/mux isn't reachable — surface that rather than guessing.
2. **Inspect before mutating.** `wezterm cli list --format json` and `wezterm cli list-clients --format json`. Use these to find the right `workspace`, identify candidate panes by `title`/`cwd`, and capture the exact `window_id` / `tab_id` / `pane_id` to act on.
3. **Mutate with the smallest set of calls.** `spawn` / `split-pane` to create; `activate-pane` / `activate-pane-direction` / `activate-tab` to focus; `set-tab-title` / `set-window-title` / `rename-workspace` to label; `send-text` / `get-text` to interact; `adjust-pane-size` / `zoom-pane` to lay out. `spawn` and `split-pane` print the new pane id on stdout — capture it.
4. **Verify.** Re-run `wezterm cli list --format json` and confirm the new panes/titles/focus match the goal. If a command was run in a pane, optionally `wezterm cli get-text --pane-id <id>` to confirm its output.

## Running a command both the user and the agent should see

When a command's output matters to the user (watching it live in WezTerm) *and* to the agent (reading the scrollback) — specs, a test run, a build, a dev-server startup — don't run it with the Bash tool in isolation. Put it in a visible pane, then read it back.

On this machine the ergonomic path is the **`wezrun`** CLI (`~/.local/bin/wezrun`, source `scripts/wezterm/wezrun.nim`):

- `wezrun exec [--fresh|--split-right|--split-bottom] [--pane-id N] [--tab-title NAME] [--lines N] [--timeout N] -- <command...>` — runs `<command>` in a visible pane (default: a tab titled `claude-run` in the agent's own window, created on first use and reused after), waits for it to finish via a unique exit-code sentinel, prints the pane's scrollback (last `--lines`, default 300) with a `=== wezrun: <cmd> · pane <id> · exit <n> ===` header, and **exits with the wrapped command's exit code**. `--timeout` is plain integer seconds (default 300; `0` = wait forever). Exit 124 = timed out; 125 = wezrun couldn't set up (not in a WezTerm pane, etc.). Crossing into another window is opt-in only — pass `--pane-id N`.
- `wezrun capture [--pane-id N | --tab-title claude-run] [--lines N]` — reprint a pane's scrollback later (default: the `claude-run` pane in this window). `--pane-id` reads any pane.
- No `--kill`: wezrun's internal `kill-pane` would bypass the `wezterm-guard` confirm hook (which only sees the agent's Bash-tool calls), so tear panes down with a raw `wezterm cli kill-pane --pane-id N` — which the guard covers. The reused `claude-run` pane persisting is intentional.

The portable fallback — the raw `wezterm cli spawn → send-text → poll sentinel → get-text` sequence, for hosts without `wezrun` — is in **`references/recipes.md`** under "Run a command in a shared pane and read the result back". Key gotcha there: `wezterm cli send-text --pane-id N 'cmd\n'` sends a literal backslash-n, not a newline — use `printf 'cmd\n' | wezterm cli send-text --pane-id N --no-paste` (stdin form, `--no-paste` so the newline actually submits) or `$'cmd\n'` ANSI-C quoting.

## Output format when acting on a user request

Keep it tight:
1. **Plan** — 3–7 bullets of what will change.
2. **Commands** — a single code block, IDs captured into shell variables where they chain.
3. **Expected outcome** — concrete checks (new pane ids exist, tab titled `X`, focus on pane `N`).
4. **Rollback** — only when relevant (e.g. "to undo, `wezterm cli kill-pane --pane-id <id>` — will prompt for confirmation").

Skip extra prose unless asked.

## Reference files

Load these as needed — don't preload both:

- **`references/commands.md`** — every `wezterm cli` subcommand with concrete invocations and flags (inspect / create / focus / titles & workspaces / interact / layout / destructive), plus the official doc URLs and a note on the `wezterm-guard` hook.
- **`references/recipes.md`** — agent-friendly composed patterns: new titled tab, 3-pane dev layout, predictable focus moves, the shared-pane command-run-and-capture recipe (`wezrun` first, raw `wezterm cli` as the portable fallback), workspace rename, resize/zoom.
