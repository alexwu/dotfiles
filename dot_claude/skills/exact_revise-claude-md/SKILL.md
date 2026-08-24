---
name: revise-claude-md
description: Capture what a coding session produced — new features, commands, conventions, gotchas, and cross-module relationships — into the right memory surface (CLAUDE.md, .claude/rules/, CLAUDE.local.md, AGENTS.md, or a skill). Use at the end of a session when the user says write this down, save what we learned, capture the session, update CLAUDE.md with what we built, remember this for next time, document what changed, or asks what from this session is worth persisting. The lighter session-end capture pass — claude-md-improver is the full audit, decompose-claude-md is the refactor.
---

<!--
Source plugin: https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management
Source doc: https://code.claude.com/docs/en/memory.md
Sibling skills: claude-md-improver (full audit), decompose-claude-md (refactor)
See the claude-md-improver skill's SOURCES.md for re-sync guidance.
Last synced: 2026-05-04
-->

# Revise CLAUDE.md

Review this session and capture what's worth persisting. The goal is not just gotchas — it's also **new features built**, new commands introduced, new conventions established. Future sessions need to know what exists in this codebase.

## User-scope guard

`~/.claude/CLAUDE.md` and `~/.claude/rules/*.md` load into **every project on the machine**. This skill may route a candidate there and propose the diff; it must never apply one unless the user asked for global/user-level changes in this session or approves that specific diff after you name it. Approving the batch is not approval for these — list them separately and default to skipping. Same rule as `claude-md-improver` Phase 6.

## Step 1: Reflect — what changed in this session?

Walk these buckets:

**A. New features / systems / files built this session**
- New modules, scripts, or binaries
- New hooks, agents, skills, or commands
- New CLI tools or executables wired up
- New integration points (MCP servers, external services)

**B. New commands or workflows discovered**
- Build/test/deploy commands
- Debugging procedures that worked
- Tooling commands (`fd`, `rg`, `ast-grep`) that were the right pick

**C. Gotchas and non-obvious patterns hit**
- Surprises that cost debugging time
- Ordering dependencies
- Configuration quirks
- Things a future session would assume incorrectly

**D. Conventions established**
- "From now on, X lives at Y"
- "Hooks must be Nim with cligen `dispatchMulti`"
- Naming/structure decisions worth preserving

**E. Cross-module relationships**
- Init order, lifecycle dependencies
- Shared state surfaces
- Interface boundaries that aren't obvious from the code

For each bucket, list candidates. **Do not filter yet.** Filtering happens in step 4.

## Step 2: Discover memory surfaces

```bash
# Project surfaces
fd -uHI -e md -t f '^(CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md)$' .
fd -uHI -e md . .claude/rules 2>/dev/null

# User surfaces — read to route and to catch conflicts; never written without a go-ahead
ls ~/.claude/CLAUDE.md 2>/dev/null
fd -uHI -e md . ~/.claude/rules 2>/dev/null
```

Note which exist; the routing in step 3 picks among them.

## Step 3: Route each candidate to the right surface

For each candidate from step 1, decide its surface using this tree:

```
Multi-step procedure (>3 steps)?
├─ Yes → SKILL — propose a skill stub at .claude/skills/<name>/SKILL.md
│        (or ~/.claude/skills/<name>/ if it's genuinely cross-project)
└─ No → continue

Only relevant when working with files in one directory or filetype?
├─ Yes → .claude/rules/<topic>.md  with paths: frontmatter
└─ No → continue

Personal/machine-specific (sandbox URL, creds, local pref)?
├─ Yes → CLAUDE.local.md (gitignored). Default here.
│        Cross-project? ~/.claude/CLAUDE.md — PROPOSE-ONLY, see "User-scope guard"
└─ No → continue

A learning Claude itself would notice (correction, inferred preference)?
├─ Yes → defer to AUTO MEMORY — don't write manually; mention to user
└─ No → continue

Same instructions other agents (Codex, Cursor) need?
├─ Yes → AGENTS.md — add to AGENTS.md, ensure CLAUDE.md has @AGENTS.md
└─ No → CLAUDE.md (project root or .claude/CLAUDE.md)
```

For each candidate, output:

```
**<Bucket>**: <one-line summary>
**Surface:** <chosen surface + path>
**Why this surface:** <one-line justification>
```

If a CLAUDE.md is already approaching 200 lines, prefer extracting to `.claude/rules/` instead of growing CLAUDE.md.

## Step 4: Filter — what earns its place?

Drop candidates that fail any of these:

- ❌ Obvious from the code or directory layout
- ❌ Generic best practice not specific to this project
- ❌ One-off debugging that won't recur
- ❌ Already covered elsewhere (deduplicate)
- ❌ Auto memory will catch it without manual help

Keep candidates that pass all of:

- ✅ Project-specific
- ✅ Helps a future session do something it otherwise would have to rediscover
- ✅ Most concise possible expression
- ✅ Belongs on the chosen surface (not just CLAUDE.md by default)

## Step 5: Show proposed changes

For each surviving candidate, show:

```
### Update: <surface path>

**Why:** <one-line reason>

**Bucket:** <feature | command | gotcha | convention | relationship>

```diff
+ <addition — keep tight>
```
```

If the addition introduces a new file (rule file, skill, CLAUDE.local.md), show the full file content, not just a diff.

If multiple changes target the same file, group them so the user sees the full set in context.

Put any user-scope candidates under their own heading — **"Targets your global prompt — not applied without your go-ahead"** — so approving the batch can't sweep them in.

## Step 6: Apply with approval

Ask the user which changes to apply. Apply only the approved ones.

For new files, create them. For edits, preserve surrounding structure (don't reflow the whole section to add one line).

Skip every user-scope candidate unless it was explicitly approved by itself. Close by naming what you skipped: "N candidates target `~/.claude/CLAUDE.md` — say the word and I'll apply them."

After applying, run `wc -l` on any modified CLAUDE.md and warn if any went over 200 lines — point at the `decompose-claude-md` skill if so.

## Output style

- Lead with a short summary: "Found N candidates across {features, commands, gotchas, conventions}; M survived filtering."
- Group by bucket so the user sees what was built vs what was learned
- Keep each candidate to 1–2 lines
- Don't editorialize — these are discrete changes to apply or skip

## Notes for the agent

- The capture explicitly includes **new features**, not just gotchas. The legacy version of this workflow skewed toward problems-and-fixes; this one captures the positive changes too, because future sessions need to know what exists.
- Don't write to `~/.claude/projects/<proj>/memory/` — that's auto memory and Claude owns it.
- When unsure between CLAUDE.md and auto memory, prefer asking the user briefly: "should this be an explicit instruction (CLAUDE.md) or a learning Claude can re-discover (auto memory)?"
- `claude-md-improver` (sibling) is for full audits; this skill is the lighter session-end capture pass.
