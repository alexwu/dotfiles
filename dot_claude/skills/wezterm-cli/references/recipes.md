# WezTerm CLI recipes

Agent-friendly composed patterns. The common shape: capture IDs from `wezterm cli list --format json`,
then operate on them by id. `spawn` and `split-pane` print the new pane id on stdout — capture it.

## New titled tab in the current window

1. Get a `window_id` from `wezterm cli list --format json`.
2. Spawn into that window.
3. Title the tab via the returned pane id.

```sh
pane_id="$(wezterm cli spawn --window-id 0 --cwd "$PWD")"
wezterm cli set-tab-title --pane-id "$pane_id" "repo"
```

## 3-pane dev layout in the current tab

Keep the current pane as the editor (or whatever's running), add a right pane for the server, and
split a bottom pane under it for tests.

```sh
server_id="$(wezterm cli split-pane --right --percent 35 --cwd "$PWD")"
wezterm cli set-tab-title --pane-id "$server_id" "server"

tests_id="$(wezterm cli split-pane --pane-id "$server_id" --bottom --percent 50 --cwd "$PWD")"
wezterm cli set-tab-title --pane-id "$tests_id" "tests"
```

To actually start things (only when the user wants the commands run — `--no-paste` so the trailing
newline submits; see the `send-text` bullet in `commands.md`):

```sh
printf 'npm run dev\n' | wezterm cli send-text --pane-id "$server_id" --no-paste
printf 'npm test\n'    | wezterm cli send-text --pane-id "$tests_id"  --no-paste
```

## Run a command in a shared pane and read the result back

Use when a command's output matters to *both* the user (watching it live) and the agent (reading
the scrollback): specs, a test run, a build, a dev-server startup log, a one-off diagnostic.

### Preferred: `wezrun` (this machine)

`wezrun` (`~/.local/bin/wezrun`, source `scripts/wezterm/wezrun.nim`) wraps the whole dance into one
command, scoped to the agent's own WezTerm window:

```sh
# Run it; blocks until done; prints the pane's scrollback; exits with the wrapped command's code.
wezrun exec -- just test                          # reuses (or creates) a `claude-run` tab
wezrun exec --timeout 600 -- bun run build        # plain integer seconds; 0 = wait forever
wezrun exec --fresh -- npm run dev                # a new pane instead of reusing claude-run
wezrun exec --split-right -- watch -n5 git status  # split off our own pane (stays untitled)
wezrun exec --pane-id 12 -- ./deploy.sh           # an existing pane — the only way to cross windows

# Re-read a pane's scrollback later:
wezrun capture                                    # the claude-run pane in this window
wezrun capture --pane-id 12 --lines 800
```

- stdout is the pane's last `--lines` lines (default 300) verbatim, after a
  `=== wezrun: <cmd> · pane <id> · exit <n> ===` header — so you get the exit code without parsing,
  and the same view the user sees on screen. Don't pipe it through `head`/`tail`; read it whole.
- exit 124 = timed out; exit 125 = wezrun couldn't set up (not in a WezTerm pane, `wezterm` missing,
  pane not found, …); otherwise it's the wrapped command's exit code (0–255).
- `--fresh` and `--split-*` always make a new pane (don't reuse `claude-run`). A `--split-*` pane is
  left untitled (a split shares its source pane's tab, so titling it would retitle the source pane's
  tab too) — re-target it with `--pane-id`.
- No `--kill` — tear panes down with a raw `wezterm cli kill-pane --pane-id N` (which trips the
  `wezterm-guard` confirm hook; `wezrun`'s own subprocess wouldn't). The reused `claude-run` pane
  persisting between runs is the point.

### Fallback: raw `wezterm cli` (hosts without `wezrun`)

The shape: get a dedicated pane → send the command with a trailing newline → wait for completion →
`get-text` the pane. `send-text` is fire-and-forget — it returns once the keystrokes are delivered,
not when the command exits — so append an exit-code sentinel and poll for it (capped, so you never
hang):

```sh
# 1. Dedicated pane for the run — split right, titled so the user can see what it is.
run_id="$(wezterm cli split-pane --right --percent 40 --cwd "$PWD")"
wezterm cli set-tab-title --pane-id "$run_id" "specs"

# 2. Run the command, then printf a unique sentinel carrying the exit code.
#    stdin + --no-paste guarantees the trailing \n actually submits; pick a sentinel that
#    can't collide with real output.
printf 'just test; printf "\\n__WEZ_DONE_%%d__\\n" "$?"\n' \
  | wezterm cli send-text --pane-id "$run_id" --no-paste

# 3. Poll the pane until the sentinel shows up.
done=""
for _ in $(seq 1 120); do            # 120 * 2s = 4 min ceiling — adjust per expected runtime
  out="$(wezterm cli get-text --pane-id "$run_id")"
  case "$out" in *"__WEZ_DONE_"*) done=1; break ;; esac
  sleep 2
done
[ -n "$done" ] || echo "timed out waiting for the run to finish" >&2

# 4. Read the final output — pull scrollback, not just the viewport — and surface it.
wezterm cli get-text --pane-id "$run_id" --start-line -500
```

Notes:
- `__WEZ_DONE_0__` means success; any other number is the failing exit code.
- `get-text` without `--start-line` returns only the visible viewport. Use a negative
  `--start-line` (e.g. `-500`, `-2000`) to reach back into scrollback for long output. Add
  `--escapes` if you need the ANSI colors; omit it for clean plain text.
- Don't want a long-lived shell? `wezterm cli spawn --cwd "$PWD" -- bash -lc 'just test'` runs the
  command directly in a new tab — but the pane closes the instant it exits, so `get-text` it
  before then, or keep the pane open: `... -- bash -lc 'just test; exec bash'`.
- Tear down the pane only if the user wants it gone: `wezterm cli kill-pane --pane-id "$run_id"`
  (this trips the `wezterm-guard` confirmation — expected; see `references/commands.md`).

## Predictable focus moves

```sh
# By id:
wezterm cli activate-pane --pane-id 123

# By direction, from the current pane:
wezterm cli activate-pane-direction Left

# Discover the neighbor's id without moving focus, then act on it:
neighbor="$(wezterm cli get-pane-direction Right)"
wezterm cli activate-pane --pane-id "$neighbor"
```

## Rename a workspace

```sh
wezterm cli rename-workspace --workspace default my-project
```

## Resize and zoom

```sh
wezterm cli adjust-pane-size --pane-id 123 Left --amount 5
wezterm cli zoom-pane --pane-id 123 --toggle
```
