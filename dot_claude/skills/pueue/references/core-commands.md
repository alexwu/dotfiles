# pueue core commands (verified against v4.0.4)

All flags below were captured from `pueue <subcommand> --help` on the user's installed v4.0.4. Both short and long forms are noted.

## `pueue add` — enqueue a task

```bash
pueue add [OPTIONS] <COMMAND>...
```

Two equivalent forms:

```bash
pueue add 'ls $HOME && echo hello'           # single string, runs via sh -c
pueue add -- ls -al "/tmp/path with spaces"  # varargs, after `--`
```

The `--` form is necessary when the command starts with a flag, or when you need explicit argv splitting. Either way, the daemon runs the result through `sh -c`.

### Flags

| Flag | Short | Purpose |
|---|---|---|
| `--working-directory <DIR>` | `-w` | CWD for the task (else daemon's CWD, NOT your shell's) |
| `--label <LABEL>` | `-l` | Free text shown in status; **required for Claude tasks** as `"claude: <descriptor>"` |
| `--print-task-id` | `-p` | Print only the numeric ID — for capturing in scripts |
| `--group <NAME>` | `-g` | Submit to a specific group (else `default`) |
| `--after <ID>...` | `-a` | Run only after listed tasks succeed; fails if any dep fails |
| `--stashed` | `-s` | Create stashed (queued but not started); enqueue later |
| `--immediate` | `-i` | Start immediately, ignore parallel slot limit |
| `--follow` | | With `--immediate`, also tail the output |
| `--delay <DURATION>` | `-d` | Defer enqueue (e.g. `--delay 30s`, `--delay 1h`) |
| `--priority <N>` | `-o` | Higher = sooner; default 0; affects only queued tasks |
| `--escape` | `-e` | Pre-escape special chars; disables `&&`, `&>`, etc. |

### Capture-and-chain pattern

```bash
TASK=$(pueue add --print-task-id --label "claude: build" -w "$(pwd)" -- swift build)
NEXT=$(pueue add --print-task-id --label "claude: test" --after "$TASK" -w "$(pwd)" -- swift test)
```

### Stashed flow (set env, then enqueue)

```bash
TASK=$(pueue add --stashed --print-task-id --label "claude: train" -- python train.py)
pueue env set "$TASK" BATCH_SIZE 64    # NOTE: 3 separate positional args, NOT KEY=VALUE
pueue env set "$TASK" LR 0.001
pueue enqueue "$TASK"
```

`pueue env set/unset` works only on stashed/queued tasks — running tasks have an immutable env snapshot from when they started.

## `pueue status` — list tasks

```bash
pueue status                  # human table
pueue status --json           # full JSON dump
pueue status --group <NAME>   # filter to one group
pueue status --json | jaq '.tasks["42"]'   # one task by ID
```

### JSON shape (verified on running daemon)

```jsonc
{
  "tasks": {
    "42": {
      "id": 42,
      "command": "...",                      // the actual sh -c arg
      "original_command": "...",             // pre-alias-resolution
      "path": "/working/directory",
      "envs": { "PATH": "...", ... },        // env snapshot
      "group": "default",
      "label": "claude: foo",                // null if unset
      "dependencies": [],                    // task IDs from --after
      "priority": 0,
      "created_at": "2026-04-29T...",
      "status": "Running"                    // STRING for in-flight
    },
    "43": {
      "...": "...",
      "status": {                            // OBJECT for terminal
        "Done": {
          "enqueued_at": "...",
          "start": "...",
          "end": "...",
          "result": "Success"                // or "Failed", "FailedToSpawn", "Killed"
        }
      }
    }
  },
  "groups": { "default": { "status": "Running", "parallel_tasks": 1 } }
}
```

In-flight `status` strings: `"Queued"`, `"Stashed"`, `"Locked"`, `"Paused"`, `"Running"`.

The `keys[0]` jaq trick normalizes both shapes:

```bash
pueue status --json | jaq -r '
  .tasks | to_entries[]
  | "\(.key)\t\(.value.label // "(no label)")\t\(.value.status | if type=="object" then keys[0] else . end)"
'
```

## `pueue log` — finished task output

```bash
pueue log 42                  # truncated tail
pueue log 42 --full           # entire output
pueue log 42 --json           # structured
pueue log 42..50              # range syntax
```

Logs are also persisted on disk at `~/Library/Application Support/pueue/task_logs/<id>.log` and survive `pueue clean` (clean only removes from in-memory state).

## `pueue follow` — tail running output

```bash
pueue follow 42               # tail -f equivalent
pueue follow                  # follow most recently added running task
```

Exits when the task finishes. Ctrl-C to detach without killing the task.

## `pueue wait` — block until done

```bash
pueue wait 42                 # wait for one task
pueue wait 42 --quiet         # no progress output
pueue wait --group downloads  # all tasks in a group
pueue wait --all              # all tasks everywhere
pueue wait --status Running   # wait for tasks to reach a state
```

## `pueue kill` — terminate

```bash
pueue kill 42                 # kill one running task (default SIGTERM)
pueue kill --group downloads  # kill whole group
pueue kill --all              # kill everything
pueue kill --signal HUP 42    # specific signal
```

## `pueue restart` — re-run a finished task

```bash
pueue restart --in-place 42        # SAFE: reuse the existing task; overwrites its log
pueue restart 42                    # creates a NEW task with new ID (FOOTGUN — see SKILL.md)
pueue restart --all-failed --failed-in-group downloads   # group-scoped retry
pueue restart --edit 42             # open $EDITOR to tweak command first
```

If `restart_in_place: true` is set in `pueue.yml` (client section), plain `pueue restart` defaults to in-place; use `--not-in-place` for the new-task variant. The user's current config has `restart_in_place: false`, so `--in-place` must be explicit.

## `pueue clean` / `pueue reset` — cleanup

```bash
pueue clean                       # remove finished from in-memory list (logs survive on disk)
pueue clean -g downloads          # group-scoped
pueue clean --successful-only

pueue reset                       # KILLS all tasks AND wipes everything — use sparingly
```

## `pueue group` / `pueue parallel` — concurrency control

```bash
pueue group                                     # list groups
pueue group add downloads                       # create
pueue group add downloads --parallel 2          # create with limit
pueue group remove downloads                    # destroy (group must be empty)

pueue parallel 4 --group downloads              # set limit on existing group
pueue parallel 0 --group downloads              # 0 = unlimited
```

Each group runs independently. Within a group, `parallel N` = up to N tasks concurrent.

## `pueue stash` / `pueue enqueue` / `pueue start` / `pueue pause`

```bash
pueue stash 42                # move queued task back to stashed (won't auto-start)
pueue enqueue 42              # move stashed → queued
pueue start 42                # resume paused task or whole group
pueue pause 42                # pause running task (SIGSTOP equivalent)
pueue pause --group downloads
pueue pause --all
```

## `pueue send` — send stdin to a running task

```bash
pueue send 42 "y\n"           # answer a confirmation prompt
```

Useful when a task hangs on `Are you sure? [y/N]`. Prefer `--yes` flags on the queued command if available.

## `pueue edit` — adjust a task's properties

```bash
pueue edit 42                 # opens $EDITOR with the task's command/path/label
```

Only works on Stashed/Queued tasks — can't edit a running task.

## `pueue env set` / `pueue env unset`

```bash
pueue env set <TASK_ID> <KEY> <VALUE>
pueue env unset <TASK_ID> <KEY>
```

Three positional args for `set` (NOT `KEY=VALUE`). Works on stashed/queued tasks only — running tasks have an immutable env snapshot.

## `pueue completions` — shell completion

```bash
pueue completions zsh ~/.config/zsh/completions
pueue completions bash ~/.bash_completion.d
```

Already auto-generated by Homebrew on macOS — check `brew --prefix pueue`.

## `pueue shutdown` — stop the daemon

```bash
pueue shutdown                # only useful when daemon ISN'T managed by a service manager
```

On this machine the daemon is managed by `brew services` / launchd, so use `brew services stop pueue` instead — it's idempotent and the LaunchAgent won't auto-restart it.
