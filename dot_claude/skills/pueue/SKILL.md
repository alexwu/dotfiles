---
name: pueue
description: Use whenever the user wants to queue a shell command, run something in the background, kick off a long download (hf/huggingface/ollama/curl/aria2/git clone/large file pull), start a build or test suite that takes more than ~30 seconds, batch jobs, chain steps with dependencies, or check on tasks from a previous Claude session. Pueue's daemon is fully separate from Claude Code, so queued tasks survive session restarts, terminal closures, and reboots — agents picking up from a prior session should always check `pueue status` first before assuming nothing is running. Also use when the user mentions "in the background", "fire and forget", "after the build finishes", "in parallel", "what's still running", "pick up where we left off", "kick off", or any pueue-specific term (group, callback, --after, restart, follow, log, env set).
---

# pueue — persistent shell job queue

`pueue` is a Rust daemon (`pueued`) that owns a persistent queue of shell commands. Each task gets a numeric ID, full stdout/stderr capture, exit code, timing, and an environment snapshot. State lives at `~/Library/Application Support/pueue/state.json`. The daemon survives terminal closures, SSH disconnects, and Claude Code session restarts — that's the entire reason to prefer it over plain `&` or Claude's native background tools.

> Portability note: this skill body is plain markdown. To reuse it under Codex / Cursor / Aider, copy the body into the host agent's rules format and rewrite the frontmatter — no other changes needed.

## When to route through pueue

| Situation | Use pueue? |
|---|---|
| Command will take more than ~30 seconds | yes |
| Need the task to survive a Claude restart | yes |
| Batching ≥3 similar items | yes |
| Want logs/timing recoverable later | yes |
| Sub-second commands, simple `ls`/`cat`/`echo` | no |
| Interactive REPLs, editors, anything wanting a TTY | no |
| GUI apps | no |

When unsure, default to pueue for anything that *might* run long. The overhead is ~100ms; the recovery story is worth it.

## The Claude labeling convention

Every `pueue add` issued by Claude must include `--label "claude: <descriptor>"`. The `claude:` prefix is how a future session finds tasks Claude itself launched. Match the user's existing convention `<domain>: <descriptor>` (their existing tasks use `mlx-audio: <model>`).

```bash
# Simple command (no shell metachars)
pueue add --label "claude: <descriptor>" -w "<dir>" -- <command>

# Compound command (with &&, ||, ;, |, >, <, or quoted args containing spaces)
pueue add --label "claude: <descriptor>" -w "<dir>" '<full command as a single string>'
```

Don't omit `--label`. Don't omit `-w` if the working directory matters (it usually does — pueued's CWD is wherever the daemon was launched, which is *not* your shell's CWD). The `--` + argv form silently breaks for compound commands because pueue joins argv with spaces — see footgun #1 in `references/pitfalls-and-debugging.md`.

Descriptors should be short, lowercase, hyphenated, and identify the *what*, not the *when*: `claude: dl-llama-70b`, `claude: ios-build`, `claude: pytest-myproject`. Pueue records timestamps automatically — no need to encode them in the label.

## Quick command reference

| Action | Command |
|---|---|
| Add a simple task | `pueue add --label "claude: foo" -w "$PWD" -- <cmd>` |
| Add a compound task (with `&&`/pipes/redirects) | `pueue add --label "claude: foo" -w "$PWD" '<cmd1> && <cmd2>'` |
| Capture task ID | `TASK=$(pueue add --print-task-id --label "claude: foo" -- <cmd>)` |
| Status (human) | `pueue status` |
| Status (JSON) | `pueue status --json` |
| Tail running task | `pueue follow <id>` |
| View finished output | `pueue log <id> --full` |
| Block until done | `pueue wait <id> --quiet` |
| Kill a task | `pueue kill <id>` |
| Restart in place | `pueue restart --in-place <id>` *(see footgun below)* |
| Chain after deps | `pueue add --after <id1> <id2> -- <cmd>` |
| Make a group | `pueue group add <name> && pueue parallel <N> --group <name>` |

For the full surface (stash, enqueue, env set, parallel tweaks, all status JSON shapes), see `references/core-commands.md`.

## Cross-session discovery — picking up Claude's prior work

When a fresh session starts and the user asks "what's running?" or "pick up where we left off", run:

```bash
pueue status --json | jaq -r '
  .tasks | to_entries[]
  | select(.value.label // "" | startswith("claude:"))
  | "\(.key)\t\(.value.label)\t\(.value.status | if type=="object" then keys[0] else . end)"
'
```

Output is `<id>\t<label>\t<status>` per task. In-flight status is a string (`Running`, `Queued`, `Stashed`, `Paused`); terminal status is an object whose key is `Done` (check `.status.Done.result` for `Success`/`Failed`/`FailedToSpawn`/`Killed`). The `keys[0]` trick handles both.

For any failed task, fetch the log with `pueue log <id> --full` before deciding what to do — don't auto-restart. Some failures (missing data, bad args, schema mismatch) will never succeed; surface findings to the user.

For deeper patterns (adopting orphan tasks, cleaning vs preserving history, resuming dependency chains), see `references/claude-cross-session.md`.

## Daemon health quick check

```bash
brew services list | rg pueue            # expect: pueue ... started ...
pueue status                              # any non-error output = daemon is up
```

If `pueue status` errors with `Connection refused` or `Failed to connect`, the daemon is down or its socket is stale. See `references/daemon-lifecycle.md` for `brew services restart pueue` and stale-socket recovery.

## The big footgun: `pueue restart` creates a new task by default

Verified on this machine (v4.0.4 with `restart_in_place: false`):

```
pueue restart 12   →  task 13 enqueued. Task 12 stays as Done.
```

In one reported field incident, agents restart-looping failed tasks grew 60 jobs to ~12,800.

Always use `pueue restart --in-place <id>` (short: `-i`) when retrying a single failed task. Never use `pueue restart --all-failed` without `--failed-in-group <name>` — it touches every failed task across all groups and can balloon the queue.

Before restarting at all: read `pueue log <id> --full`. For more footguns (working directory, quoting, bare `&` detachment, no GUI/aliases, stdin handling), see `references/pitfalls-and-debugging.md`.

## When something breaks

1. `pueue status` — daemon up? task in expected state?
2. `pueue log <id> --full` — what did the command actually print?
3. `sh -c "<your queued command>"` interactively — does it work outside pueue?
4. `references/pitfalls-and-debugging.md` — quoting, working-dir, stdin, detachment, restart.
5. `references/daemon-lifecycle.md` — daemon recovery if connect fails.

## References

- `references/core-commands.md` — full command surface, all flags, JSON shape table
- `references/recipes.md` — concrete patterns for downloads, builds, DAGs, sync wrappers
- `references/pitfalls-and-debugging.md` — footguns and how to recover
- `references/daemon-lifecycle.md` — config files, brew services, launchd, stale socket
- `references/claude-cross-session.md` — cross-session continuity, adopting orphan tasks
