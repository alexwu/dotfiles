# pueue daemon lifecycle (macOS, Homebrew)

The daemon is `pueued`. On this machine it's started by `~/Library/LaunchAgents/homebrew.mxcl.pueue.plist` (a LaunchAgent), managed via `brew services`.

## Status & control

```bash
brew services list | rg pueue          # status
brew services start pueue              # start (if stopped)
brew services restart pueue            # restart (config reload)
brew services stop pueue               # stop
```

Behind the scenes, `brew services` calls `launchctl bootstrap/bootout`. If `brew services` itself misbehaves (rare), drop down to launchctl:

```bash
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.pueue.plist
launchctl load   ~/Library/LaunchAgents/homebrew.mxcl.pueue.plist
```

## Stale socket recovery

Symptom: `pueue status` errors with `Connection refused` or `Failed to connect`, daemon process appears running.

```bash
rm "$HOME/Library/Application Support/pueue/pueue_$USER.socket"
brew services restart pueue
pueue status                            # should now respond
```

## Config file (`pueue.yml`)

Path: `~/Library/Application Support/pueue/pueue.yml`. Reload requires daemon restart (`brew services restart pueue`).

The user's config is mostly defaults. Top-level sections:

| Section | What it controls |
|---|---|
| `client` | Local CLI behavior — display format, edit mode, restart-in-place default, confirmation prompts |
| `daemon` | Server-side — `pause_group_on_failure`, `compress_state_file`, `callback` template, `env_vars`, `shell_command` |
| `shared` | Connection — Unix socket vs TCP, host/port, TLS cert/key paths, shared secret |
| `profiles` | Named overlay configs — selected via `pueue --profile <name>` |

Notable settings the user may want to tweak someday:

```yaml
client:
  restart_in_place: true         # makes plain `pueue restart` safe by default

daemon:
  callback: 'osascript -e "display notification \"Task {{id}} {{result}}\" with title \"pueue\""'
  callback_log_lines: 10         # how many tail lines exposed to {{output}}
  pause_group_on_failure: true   # auto-pause group on first failure
  compress_state_file: true      # zstd-compress state.json (~10:1)
```

Callback template variables: `{{id}}`, `{{command}}`, `{{path}}`, `{{group}}`, `{{label}}`, `{{result}}`, `{{exit_code}}`, `{{enqueue}}`, `{{start}}`, `{{end}}`, `{{output}}`.

## Where data lives

| Path | Purpose |
|---|---|
| `~/Library/Application Support/pueue/pueue.yml` | Config |
| `~/Library/Application Support/pueue/state.json` | Live task metadata (read-only inspection) |
| `~/Library/Application Support/pueue/task_logs/<id>.log` | Per-task stdout/stderr |
| `~/Library/Application Support/pueue/pueue_$USER.socket` | Unix socket |
| `~/Library/Application Support/pueue/pueue.pid` | Daemon PID |
| `~/Library/Application Support/pueue/log/` | Daemon's own logs (separate from task logs) |
| `~/Library/Application Support/pueue/certs/` | TLS cert/key (unused with Unix socket transport) |
| `~/Library/Application Support/pueue/shared_secret` | Auth secret (Unix socket — usually irrelevant) |

## State bloat

`state.json` grows with every completed task. Per terrylica's field measurements, ~50K completed tasks brings it to ~80MB and slows `pueue add` from ~100ms to ~1.3s per call.

Mitigations:

```bash
pueue clean                           # remove finished from in-memory list
pueue clean -g default --successful-only

# In pueue.yml
daemon:
  compress_state_file: true           # ~10:1 zstd compression
```

For Claude's typical use (single user, modest job count, occasional long downloads), this is unlikely to bite — but if `pueue add` ever feels slow, check `state.json` size with `du -h ~/Library/Application\ Support/pueue/state.json`.

## Upgrading

```bash
brew upgrade pueue
brew services restart pueue
```

If a major version bump (e.g. 4.x → 5.x) lands, check the [Pueue changelog](https://github.com/Nukesor/pueue/blob/main/CHANGELOG.md) — protocol breaks may need a state-file migration.
