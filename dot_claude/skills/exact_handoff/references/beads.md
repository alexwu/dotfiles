# Beads snapshot (read-only)

Load this only when `.beads/` exists at the repo root. Beads (`bd`) is a graph
issue tracker; open work already lives there, so the handoff **references bead
IDs** instead of duplicating task text as checkboxes.

**Hard rule: read-only.** During a handoff, run only query commands. Never
`bd create|update|close|claim|note|dep|import`, and never `bd dolt push|pull|commit`.
The handoff records state; the working session already owns any bead mutations.
The Dolt store is gitignored and synced on the user's own cadence — don't touch it.

## What to capture

Snapshot the beads relevant to this session — what you were actively working and
what's queued next:

```bash
bd list --status in_progress --json   # what you were mid-flight on
bd ready --json                       # unblocked work queued next
bd blocked --json                     # optional: what's waiting, and on what
```

Pull `id`, `title`, `status`, and `priority` from the JSON. Statuses are
`open · in_progress · blocked · deferred · closed · pinned · hooked`.

## How it goes in the doc

- **`## Open tasks`** — one line per relevant bead, ID first so pickup can
  rehydrate it, with the live status in parens:
  ```markdown
  - [ ] tools-0y6 — imager ratatui TUI (in_progress)
  - [ ] tools-rxe — chain per-step labels (open)
  ```
- **`## Linked`** — list the bare IDs on the `Beads:` line:
  ```markdown
  - Beads: tools-0y6, tools-rxe
  ```

Don't copy full descriptions into the doc — the IDs are the pointer. `pickup`
runs `bd show <id>` to pull **live** state, which may have moved since you wrote
the handoff (that's the point of referencing rather than duplicating).

## If there are no relevant beads

A beads repo whose current session doesn't map to any bead (spike, chore,
exploration) is fine — omit the `Beads:` line and use a plain checklist in
`## Open tasks`, same as a non-beads repo. Don't file a bead just to have one.
