# Claude cross-session continuity with pueue

The whole reason this skill exists: pueued is a separate daemon, so tasks Claude launches in one session survive into the next. To make that useful, we need a discovery convention and a few patterns for picking up where we left off.

## The labeling convention

Every task Claude launches gets:

```
--label "claude: <short-descriptor>"
```

The `claude:` prefix (with the trailing colon-space) is what the discovery query filters on. Match the user's existing convention: descriptors are short, lowercase, hyphenated, and identify the *what*, not the *when* (e.g. `claude: dl-llama-70b`, not `claude: 2026-04-29-download`). Pueue records the timestamps automatically.

## Discovery query

```bash
pueue status --json | jaq -r '
  .tasks | to_entries[]
  | select(.value.label // "" | startswith("claude:"))
  | "\(.key)\t\(.value.label)\t\(.value.status | if type=="object" then keys[0] else . end)"
'
```

Output (tab-separated `<id>\t<label>\t<status>`):

```
14	claude: dl-llama-3.2-70b	Running
15	claude: ios-build	Done
16	claude: ios-test	Done
```

For a deeper look:

```bash
# All claude tasks with full status objects
pueue status --json | jaq '[.tasks | to_entries[]
  | select(.value.label // "" | startswith("claude:"))
  | {id: .key, label: .value.label, group: .value.group, status: .value.status, command: .value.command}]'

# Just the failures
pueue status --json | jaq '[.tasks | to_entries[]
  | select(.value.label // "" | startswith("claude:"))
  | select(.value.status | type == "object" and .Done.result != "Success")
  | {id: .key, label: .value.label, result: .value.status.Done.result}]'
```

## Workflow: "what's still running?"

When the user opens a fresh session and asks anything like "what's running", "pick up where we left off", "what's queued", "is anything still going":

1. Run the discovery query.
2. Group by status: in-flight (Running/Queued/Stashed/Paused) vs terminal (Done with Success/Failed/Killed/FailedToSpawn).
3. For in-flight: report ID, label, current state.
4. For Failed: pull the log (`pueue log <id> --full`), summarize the error, do NOT auto-restart.
5. Ask the user what they want — restart in-place, abandon, debug.

## Adopting tasks launched outside the convention

The user (or another tool) may have launched tasks without `claude:` labels. Don't re-label them silently — pueue labels are user-facing context; rewriting them is rude.

Heuristics for "this looks like something Claude might have started or should be tracking":

- Command starts with `hf download`, `cargo build`, `swift build`, `xcodebuild`, `pytest`, `npm install`, `ollama pull`.
- Long-running (currently Running for >1h, or `status.Done.start` to `now` > 1h).
- Created in the last few hours.

If you suspect an orphan that should be tracked, surface it to the user before doing anything:

> "Found task 23 — `cargo build` running for 45 minutes, no claude label. Want me to add one?"

Then if they say yes, use `pueue edit <id>` to set the label — but only on stashed/queued tasks. Running tasks have immutable metadata in v4; the practical workaround there is to remember the ID locally and re-label the eventual restart.

## When to clean vs preserve history

Pueue's history is cheap (text logs, modest state file). Default to preserving — the labels + logs are valuable cross-session context.

Clean when:
- `state.json` exceeds ~50MB (slows `pueue add` per terrylica's measurements).
- The user explicitly asks.
- A specific group has accumulated thousands of finished tasks.

Don't clean unprompted just because there are a lot of "Done" entries.

## Resuming a failed `--after` chain

If a chain fails partway through, pueue marks dependents as `Done` with `result: "DependencyFailed"` even though they never ran. To resume:

```bash
# 1. Identify the actual failed step (the root, not the cascading dependents)
pueue status --json | jaq '
  [.tasks | to_entries[]
   | select(.value.status | type == "object" and .Done.result == "Failed")
   | {id: .key, label: .value.label, command: .value.command}]'

# 2. Read the log and fix the underlying issue (manually — code change, missing input, etc.)
pueue log <root-failure-id> --full

# 3. Restart that root task in place
pueue restart --in-place <root-failure-id>
```

The dependent tasks won't auto-retry — their failed status is persistent. After the root succeeds, restart each downstream task with `--in-place` in turn.

If the chain is large, it's often cheaper to recreate it as fresh tasks with `--after` against the now-succeeded root than to restart-in-place the full ladder.

## Multi-Claude-session safety

Two Claude sessions running concurrently against the same pueue daemon is fine — pueue serializes operations through its mutex. Both sessions see each other's labeled tasks via the discovery query.

What to avoid:
- `pueue reset` from one session while the other depends on tasks (wipes everything).
- Concurrent edits to `pueue.yml` (config file isn't locked; last writer wins).
- Two sessions competing on `pueue restart --in-place` for the same ID (last one wins, may overwrite the other's log).

In practice these collisions are rare. If they happen, the discovery query is still authoritative — re-run it to see ground truth.
