---
name: handoff
description: >-
  Write a self-contained session-handoff doc so a FRESH session (after /clear,
  or a different agent — Claude, Codex, lu) can resume the work by reading one
  file. Use when the user says "hand off", "write a handoff", "save the session",
  "I'm going to clear", "dump context before I clear", "checkpoint this so I can
  pick it up later", or wants to end a session without losing where things stand.
  Captures goal, status, next steps, key files, decisions, verification commands,
  linked GitHub PR/issue, and open tasks — as beads IDs in a beads repo, else a
  markdown checklist. The `pickup` skill is the read side. Built for /clear (full
  reset), not compaction.
---

# Handoff

Write **one markdown file** that a session with **zero prior context** can read
and fully resume from. The user is going to `/clear` (a hard reset, not a
compaction) — so the doc must stand entirely on its own. It also has to be
readable by any agent, so it's plain markdown with **no** agent-specific tool
calls baked in; the reader rebuilds its own todo list from the doc.

`pickup` is the counterpart that reads it back.

## Procedure

1. **Get the path.** Pick a short slug for the work and run:
   ```bash
   handoff new <slug words>      # e.g. handoff new retry wrapper backoff
   ```
   It prints `…/.handoff/<YYYY-MM-DD-HHMM>-<slug>.md` (and creates `.handoff/`).
   Multi-word is fine — it slugifies. **This path is the only source of the
   filename format; don't hand-build the name.** Write your doc to that path.

2. **Gather the context** below from the session — goal, what's done, what's
   next, key files, decisions, how to verify. Be concrete: paths, commands,
   line-level specifics. Assume the reader has never seen this conversation.

3. **Capture linked work.** On the current branch:
   ```bash
   gh pr view --json number,url,state,title 2>/dev/null   # PR for this branch, if any
   ```
   Record it plus any GitHub issue the session was about, and the path to a plan
   file if one exists (e.g. under `docs/plans/`). Reference plans/PRs — don't
   re-paste their contents.

4. **Open tasks — beads vs checklist.**
   - **`.beads/` exists at the repo root** → this repo uses beads. **Read
     `references/beads.md` and follow it** — you'll snapshot the relevant bead
     IDs read-only, never mutate them.
   - **No `.beads/`** → list the open tasks as a plain markdown checklist in the
     doc (see template).

5. **Write the doc** to the path from step 1, using the template below.

6. **Gitignore `.handoff/`.** These are local session scratch, not project
   artifacts. If the repo doesn't already ignore them, add it (the `touch` keeps
   this safe under zsh `noclobber`, where `>>` to a missing file errors):
   ```bash
   touch .gitignore
   rg -q '(^|/)\.handoff/?$' .gitignore || printf '.handoff/\n' >> .gitignore
   ```

7. **Tell the user how to resume** — verbatim: `/clear`, then run **pickup** (no
   argument needed; it finds the newest handoff for this repo).

## Doc template

Fill every section that applies; drop a section only if it's genuinely empty.
The `# ` H1 is required — `handoff list` reads it as the title.

```markdown
# Handoff: <short title>

repo: <name> · branch: <branch> · <YYYY-MM-DD HH:MM> · agent: <claude-code|codex|lu>

## Goal
<the arc we're driving toward — the why, not just the next keystroke>

## Status
<what's done and verified; what works; what's known-broken or half-done>

## Next steps
1. <the immediate next action, concretely>
2. <then this>

## Open tasks
<beads repo → bead IDs + titles + status, per references/beads.md>
<else → a checklist:>
- [ ] <task, with enough detail to act on cold>
- [ ] <task>

## Linked
- PR: #<n> (<state>) <url>          # omit if none
- Issue: #<n> <url>                 # omit if none
- Beads: <id>, <id>                 # beads repos only; live IDs, rehydrate with `bd show`
- Plan: <path/to/plan.md>           # omit if none

## Key files
- `path/to/file` — <why it matters / what changed>

## Decisions
- <non-obvious choice> — <why, so the next session doesn't relitigate it>

## Gotchas
- <trap discovered this session that the next one would hit>

## Verification
```bash
<exact build/test/lint commands to confirm the current state before continuing>
```
```

## Gotchas

- **The doc is read cold.** After `/clear` there is no "as discussed above",
  no earlier message to lean on. Every reference must resolve inside the file.
- **Never mutate beads, never commit, never push.** Handoff is read-only w.r.t.
  the Dolt DB and git. It records state; it doesn't change it. (`references/beads.md`
  covers the read-only bead commands.)
- **`handoff new` only prints a path and makes `.handoff/`** — it does not write
  your content. You write the file at that path.
- **One handoff per `/clear`.** Don't split a single session into several docs
  unless the user asks to spin a focused task out separately.
- **Slug is for humans scanning `handoff list`** — keep it short and descriptive
  (`retry-backoff`, not `fix-stuff`).
