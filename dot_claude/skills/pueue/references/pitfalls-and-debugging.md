# pueue pitfalls & debugging

## Footguns (in rough order of how often they bite)

### 1. The `pueue add -- sh -c 'compound'` quoting trap

The most common surprise. When you write what looks like the obvious form for a compound command:

```bash
pueue add -- sh -c 'sleep 2 && echo done'
```

your interactive shell strips the single quotes during argv parsing, so pueue receives three argv items: `sh`, `-c`, and `sleep 2 && echo done`. Pueue then joins them with spaces and the daemon ends up running:

```
sh -c sleep 2 && echo done
```

That outer `sh -c sleep` interprets `sleep` as the command and `2` as `$0`, so sleep runs with no args, fails with `usage: sleep number[unit]`, and the `&&` short-circuits. Verified live on this machine.

**Two forms that actually work:**

```bash
# (a) Single-string form — preferred for anything with shell metacharacters
pueue add 'sleep 2 && echo done'
pueue add 'curl -sf example.com | jq .name > /tmp/out'
pueue add 'cd /tmp && sha256sum -c dataset.tar.gz.sha256'

# (b) --escape with explicit shell — preserves quoting in argv
pueue add --escape -- bash -c 'sleep 2 && echo done'
```

For **simple non-compound commands**, `--` + argv works fine because there's nothing to misinterpret:

```bash
pueue add -- swift build                          # fine
pueue add -- curl -fLO https://example.com/foo    # fine
pueue add -- python train.py --lr 0.001           # fine
```

**Rule of thumb:** if your command contains `&&`, `||`, `;`, `|`, `>`, `<`, backticks, or a single argv item with spaces inside (like `-destination "platform=iOS Simulator,name=iPhone 15"`), use the single-string form. Otherwise, `--` + argv is cleaner.

### 2. `pueue restart <id>` creates a new task by default

Verified on this machine (v4.0.4 with `restart_in_place: false` — the user's current config):

```
pueue restart 12   →  task 13 enqueued. Task 12 stays as Done.
```

In one reported field incident, agents restart-looping failed tasks grew 60 jobs to ~12,800.

**Always use `pueue restart --in-place <id>`** (short: `-i`). The `--in-place` form reuses the original task, overwrites its log, and keeps the ID stable.

If a user has `restart_in_place: true` in their config, plain `pueue restart` does the safe thing — but don't rely on config you didn't set. Use the explicit flag.

Before restarting at all: read `pueue log <id> --full`. Persistent failures (bad command, missing input, schema mismatch) will never succeed — surface to the user instead of looping.

### 3. Working directory is the daemon's, not your shell's

Pueued's CWD is wherever it was started — for the Homebrew launchd plist on this machine, that's effectively `/`. So:

```bash
pueue add -- ls relative/path           # FAILS — relative to /
pueue add -w "$(pwd)" -- ls relative/path   # works
```

Always pass `-w <dir>` explicitly when the command depends on its location. On macOS, `-w /tmp` resolves to `/private/tmp` via the system symlink — usually fine, but worth knowing if you're stat-comparing paths.

### 4. Bare `&` detaches the child

The daemon's `sh -c` interprets `&` as background, returns immediately, and pueue marks the task Done while your real work runs orphaned and uncaptured:

```bash
pueue add -- python long_thing.py &       # WRONG — runs orphaned, exits in 100ms
pueue add -- python long_thing.py         # right — pueue tracks it to completion
```

If you genuinely need backgrounding inside the queued command (multi-process orchestration), use `wait` so the queued shell itself blocks until everything finishes:

```bash
pueue add 'python a.py & python b.py & wait'
```

(Note the single-string form — `--` + argv would hit footgun #1.)

### 5. No interactive stdin, no TTY

Pueue runs commands with no controlling terminal. Anything that wants a prompt (`apt install`, `gh auth login`, `npm init`, `pip install --no-binary :all:`) hangs or fails.

Mitigations, in order of preference:
- Use the tool's non-interactive flag: `apt install -y`, `gh auth status` instead of `login`, `pip install --quiet`.
- Pre-pipe the answer: `pueue add 'echo y | apt install foo'` (single-string form).
- Pre-answer a hung task: `pueue send <id> "y\n"` (best effort — depends on the program reading stdin).

### 6. No GUI apps, no rc-file shell aliases

`sh -c` is not your interactive shell — `.zshrc` is not loaded, your aliases don't exist, and `$DISPLAY` is unset. GUI apps fail; aliases like `ll` (often aliased to `eza -la` in zshrc) won't resolve.

For aliases inside pueue, use the native mechanism — create `~/.config/pueue/pueue_aliases.yml`:

```yaml
ll: eza -la --icons
```

Then `pueue add -- ll /tmp` works.

### 7. `&>` (combined redirect) isn't portable

The combined-redirect operator `cmd &> file` works in zsh and modern bash but not in dash (which is `/bin/sh` on Debian/Ubuntu). Use the POSIX form:

```bash
pueue add 'cmd > file 2>&1'      # always works (single-string form)
```

On this macOS box `sh` is bash 3.2 (which supports `&>`), so this is moot locally — but if the skill ever runs against a Linux daemon, this will bite.

### 8. The JSON `status` polymorphism

`tasks[id].status` is a string for in-flight states and a single-key object for terminal states. The #1 jaq trip-up.

```bash
# WRONG — breaks on terminal status objects
pueue status --json | jaq '.tasks[] | select(.status == "Running")'

# RIGHT — normalize first
pueue status --json | jaq '
  .tasks[]
  | . + { status_name: (.status | if type=="object" then keys[0] else . end) }
  | select(.status_name == "Running")
'
```

## Debugging checklist

When a queued command misbehaves:

1. **Check status & log.**
   ```bash
   pueue status
   pueue log <id> --full
   ```

2. **Reproduce outside pueue** — isolates whether pueue is the problem.
   ```bash
   sh -c '<your queued command, verbatim>'
   ```
   If this fails interactively, the command is broken, not pueue.

3. **Inspect env snapshot.**
   ```bash
   pueue status --json | jaq '.tasks["<id>"].envs | {PATH, HOME, USER}'
   ```
   Useful for `command not found` errors (e.g. PATH missing `/opt/homebrew/bin`).

4. **Tail the persistent log file directly.**
   ```bash
   tail -f "$HOME/Library/Application Support/pueue/task_logs/<id>.log"
   ```
   Survives `pueue clean`. Also useful when `pueue follow` itself is being weird.

5. **Sanity-check the daemon.**
   ```bash
   brew services list | rg pueue
   pueue status     # error here = daemon down → see daemon-lifecycle.md
   ```

## File locations to know

| Path | Purpose |
|---|---|
| `~/Library/Application Support/pueue/pueue.yml` | Config — edit, then `brew services restart pueue` |
| `~/Library/Application Support/pueue/state.json` | Live task state. **Read-only** inspection with jaq is fine; never edit while daemon is running. |
| `~/Library/Application Support/pueue/task_logs/<id>.log` | Per-task stdout/stderr (persists past `pueue clean`) |
| `~/Library/Application Support/pueue/pueue_$USER.socket` | Unix socket. Delete + restart daemon if "Connection refused" persists. |
| `~/Library/LaunchAgents/homebrew.mxcl.pueue.plist` | LaunchAgent plist (managed by `brew services`) |
