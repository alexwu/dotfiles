---
name: pickup
description: >-
  Resume work from a session-handoff doc written by the `handoff` skill. Use when
  the user says "pick up", "pick up where I left off", "resume", "resume the
  session", "continue the last session", "load the handoff", "what was I doing" at
  the start of a fresh session, or runs this right after a /clear. With no
  argument it finds the NEWEST handoff for the current repo; pass a slug, date, or
  file path to target a specific one. Reads the doc, rebuilds the todo list,
  rehydrates beads to their LIVE state, and verifies the repo before continuing.
  Agent-agnostic (Claude, Codex, lu).
---

# Pickup

Read a handoff doc and resume from it. The doc (written by the `handoff` skill)
is self-describing — your job is to locate it, load it, reconcile it against the
repo's **current** state, and continue.

## Procedure

1. **Resolve the doc.**
   - **No argument** → newest handoff for this repo:
     ```bash
     handoff latest
     ```
     Exit 1 means there are none here. Before giving up, check for an approved
     plan (`plans/`, `.plans/`) — a session that started from plan mode has a
     self-contained plan file *instead of* a handoff, and that's the right entry
     point. Otherwise say so; don't invent one.
   - **A file path** → read it directly.
   - **A slug or date fragment** ("retry", "2026-07-23") → match against:
     ```bash
     handoff list --json
     ```
     If several match, list them and ask which; if one, use it.

2. **Read the whole doc.** Don't skim — the `## Decisions` and `## Gotchas`
   sections are what keep you from relitigating settled choices or re-hitting
   known traps.

3. **Rebuild the todo list** from `## Open tasks` using whatever native
   mechanism you have (a task list, a plan, or just the checklist in-context).

4. **Rehydrate links against LIVE state** — the doc is a snapshot; the repo has
   moved since.
   - **Beads** (any IDs on the `Beads:` line or in `## Open tasks`): run
     `bd show <id>` for each. State may have changed — a bead may now be
     `closed`, `blocked`, or reassigned. Drop closed ones, flag newly-blocked
     ones, and trust `bd` over the doc where they disagree.
   - **Plan file** (`Plan:` line): read it if present — it holds the fuller
     picture the handoff summarized.
   - **PR** (`PR:` line): `gh pr view <n>` if you need its current state.

5. **Verify before building.** Run the `## Verification` commands to confirm the
   repo is where the doc says (tests green, builds clean). Resume from a known
   state, not an assumed one.

6. **Orient the user.** Briefly restate the goal, what's done, and the immediate
   next step from the doc — then continue the work.

7. **When the checklist runs dry.** Once the doc's open tasks are done (or the
   session is wrapping up), close the loop — don't just stop:
   - Report what got done vs. what's still open, and why anything was left.
   - Surface uncommitted work (`git status --short`). **Name it; don't commit
     unasked** — committing is the user's call.
   - If real state accumulated (decisions made, things discovered, work left
     part-done), say so: **the handoff on disk is now stale** — its `## Next
     steps` describe a world that has moved — and offer to write a fresh one.

   A resumed session owes the next one its own handoff, or the chain ends here.
   `handoff → pickup → ∅` is the failure mode this step exists to prevent.

## Gotchas

- **Trust the doc, verify the world.** Files, branch, and beads may differ from
  the snapshot. If the current git branch isn't the doc's `branch:`, surface that
  before proceeding — you may be on the wrong branch.
- **`## Status` says what's already done** — don't redo completed work.
- **Newest-by-default is intentional.** If the user wanted an older session,
  they'll pass a slug/date; otherwise `handoff latest` is right.
- **Don't delete the handoff after reading.** The user decides when to clear old
  handoffs; leave them in `.handoff/`.
