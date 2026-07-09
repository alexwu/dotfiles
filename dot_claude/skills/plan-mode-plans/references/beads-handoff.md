# Beads Handoff (repos using `bd`)

**Conditional.** Everything here applies ONLY when the repo uses beads.

**Detection:** a `.beads/` directory at the repo root (`bd` walks ancestors to find
it). No `.beads/` → skip all of this, silently. Don't run `bd`, don't add a Beads
section to the plan, don't mention beads in the handoff.

Beads (`bd`) is a graph issue tracker for coding agents: issues have hash IDs like
`bd-a1b2`, form a dependency graph (`blocks`, `discovered-from`, `parent-child`, …),
and `bd ready` computes the unblocked work. The store is a Dolt DB under
`.beads/embeddeddolt/` (gitignored) — NOT a flat file, and NOT part of a normal
`git commit`. Cross-machine sync is the user's own `bd dolt push`/`bd dolt pull`
cadence; the handoff never pushes or commits.

## Why this is split across two phases

Plan mode is read-only except for the plan file, so `bd` (which writes the DB) can't
run there. The work splits:

1. **During planning (Phase 2 sketch → Phase 4 draft) — no `bd` calls.** With full
   exploration context, decompose the plan into beads issues and record them in the
   plan's `## Beads to File` section (titles, types, priorities, blocked-by links).
   Pure planning; nothing is created yet.
2. **Post-approval handoff (Phase 6) — file.** After `ExitPlanMode`, create the
   issues, capture their IDs, and write the IDs back into the plan file. Auto-filed
   (per the confirmed skill behavior), then reported.

## Plan section (drafted in Phase 4)

Add this to the plan ONLY when `.beads/` exists. Omit the whole section for a beads
repo whose plan is too trivial to warrant issues.

```markdown
## Beads to File
| Bead | Type | Priority | Blocked by | Notes |
|---|---|---|---|---|
| Add token bucket to rate limiter | feature | 1 | — | core work |
| Wire limiter into request pipeline | task | 1 | Add token bucket… | needs the bucket first |
| Backfill limiter tests | task | 2 | Wire limiter… | after wiring lands |

_Filed automatically in the post-approval handoff (Phase 6); IDs written back into
the Bead column after `bd create`._
```

- **Type** ∈ `bug | feature | task | epic | chore | decision`.
- **Priority** ∈ `0..4` (0 = highest).
- **Blocked by** references another row in this table by title — no IDs exist yet at
  draft time.

For agent-teams plans (a directory of `index.md` + numbered section files), the
`## Beads to File` section goes in `index.md`.

## Filing procedure (Phase 6, after `ExitPlanMode`)

Runs in the current session, before the compaction handoff. Create blockers first so
a dependent can reference its blocker's real ID. Capture each ID from `bd create
--json` (`--silent` also prints just the bare ID).

```bash
# 1. Create each issue plain; capture IDs from --json. Blockers first.
BUCKET=$(bd create "Add token bucket to rate limiter" -t feature -p 1 \
  -d "Core token-bucket impl in src/limiter.rs" --json | jaq -r '.id')
WIRE=$(bd create "Wire limiter into request pipeline" -t task -p 1 \
  -d "Call the bucket from the request middleware" --json | jaq -r '.id')
TESTS=$(bd create "Backfill limiter tests" -t task -p 2 \
  -d "Cover the bucket + wiring" --json | jaq -r '.id')

# 2. Add dependencies: `bd dep add <blocked> <blocker>` — FIRST arg depends on SECOND.
bd dep add "$WIRE" "$BUCKET"    # wiring depends on the bucket
bd dep add "$TESTS" "$WIRE"     # tests depend on the wiring

# 3. Verify the graph before trusting it.
bd ready --json    # only the bucket should be ready (unblocked)
bd list --json
```

Then **write the captured IDs back into the plan's `## Beads to File` table** — edit
the Bead column to `bd-a1b2 — <title>` — so the implementing session can
`bd update <id> --claim` and `bd close <id> --reason "…"` as it goes.

**Dependency direction is the #1 trap.** `bd dep add A B` = "A depends on B" = "B
blocks A" = do B first. `bd create` also accepts inline `--deps blocks:<id>`, but its
direction is easy to invert — prefer explicit `bd dep add <blocked> <blocker>` calls
and confirm with `bd ready` (only genuine starting work should come back ready).

**Report** what was filed as part of the Phase 6 handoff message, e.g.
`Filed bd-a1b2, bd-c3d4, bd-e5f6 — bucket → wiring → tests`.
