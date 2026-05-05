---
description: Capture session learnings AND new features into the right memory surface (CLAUDE.md, .claude/rules/, CLAUDE.local.md, or skill)
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

<!--
Source plugin: https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management
Source doc: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04
See dot_claude/skills/claude-md-improver/SOURCES.md for re-sync guidance.
-->

Review this session and capture what's worth persisting. The goal is not just gotchas — it's also **new features built**, new commands introduced, new conventions established. Future Claude sessions need to know what exists in this codebase.

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
- Things future Claude would assume incorrectly

**D. Conventions established**
- "From now on, X lives at Y"
- "Hooks must be Nim with cligen `dispatchMulti`"
- Naming/structure decisions worth preserving

**E. Cross-module relationships**
- Init order, lifecycle dependencies
- Shared state surfaces
- Interface boundaries that aren't obvious from the code

For each bucket, list candidates. **Do not filter yet.** Filtering happens in step 3.

## Step 2: Discover memory surfaces

```bash
# Project surfaces
fd -uHI -e md -t f '^(CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md)$' .
fd -uHI -e md . .claude/rules 2>/dev/null

# User surfaces
ls ~/.claude/CLAUDE.md 2>/dev/null
fd -uHI -e md . ~/.claude/rules 2>/dev/null
```

Note which exist; the routing in step 3 picks among them.

## Step 3: Route each candidate to the right surface

For each candidate from step 1, decide its surface using this tree:

```
Multi-step procedure (>3 steps)?
├─ Yes → SKILL — propose a skill stub at ~/.claude/skills/<name>/SKILL.md
│        (or .claude/skills/<name>/ for project-scoped)
└─ No → continue

Only relevant when working with files in one directory or filetype?
├─ Yes → .claude/rules/<topic>.md  with paths: frontmatter
└─ No → continue

Personal/machine-specific (sandbox URL, creds, local pref)?
├─ Yes → CLAUDE.local.md (gitignored) or ~/.claude/CLAUDE.md (cross-project)
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

## Step 6: Apply with approval

Ask the user which changes to apply. Apply only the approved ones.

For new files, create them. For edits, preserve surrounding structure (don't reflow the whole section to add one line).

After applying, run `wc -l` on any modified CLAUDE.md and warn if any went over 200 lines — point at `/decompose-claude-md` if so.

## Output style

- Lead with a short summary: "Found N candidates across {features, commands, gotchas, conventions}; M survived filtering."
- Group by bucket so the user sees what was built vs what was learned
- Keep each candidate to 1–2 lines
- Don't editorialize — these are discrete changes to apply or skip

## Notes for the agent

- The capture explicitly includes **new features**, not just gotchas. The legacy `/revise-claude-md` skewed toward problems-and-fixes; this version captures the positive changes too because future sessions need to know what exists.
- Don't write to `~/.claude/projects/<proj>/memory/` — that's auto memory and Claude owns it.
- When unsure between CLAUDE.md and auto memory, prefer asking the user briefly: "should this be an explicit instruction (CLAUDE.md) or a learning Claude can re-discover (auto memory)?"
- The `claude-md-improver` skill (sibling) is for full audits; this command is the lighter session-end capture pass.
