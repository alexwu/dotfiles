---
name: claude-md-improver
description: Audit and improve Claude Code memory surfaces — CLAUDE.md, .claude/rules/, CLAUDE.local.md, user-level files, and auto-memory hygiene. Use when the user asks to check, audit, update, improve, fix, refresh, or re-route their CLAUDE.md, project memory, .claude/rules/, or notes that their CLAUDE.md is out of date or growing too large. Also use when they mention CLAUDE.md maintenance, memory routing, or want to know whether a learning belongs in CLAUDE.md vs .claude/rules/ vs auto memory vs a skill.
tools: Read, Glob, Grep, Bash, Edit
---

<!--
Sources:
- Upstream plugin: https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management
- Memory doc: https://code.claude.com/docs/en/memory.md
- Last synced: 2026-05-04
See SOURCES.md (sibling) for full provenance and re-sync guidance.
-->

# CLAUDE.md Improver

Audit, route, and improve Claude Code memory surfaces. The job is **routing**, not just CLAUDE.md scoring — content frequently belongs on a different surface than where it lives.

**This skill writes to memory files** (CLAUDE.md, `.claude/rules/*.md`, CLAUDE.local.md). It does NOT write to auto memory at `~/.claude/projects/<proj>/memory/` — Claude owns that surface; we only flag drift.

## Mental model

Claude Code has multiple memory surfaces. Each has a different writer, scope, and load behavior. The most common audit failure is content sitting on the wrong surface — a path-scoped rule jammed into CLAUDE.md, a session learning written manually that auto memory would have captured, a multi-step procedure copy-pasted into project memory that should be a skill.

| Surface | Path | Loaded | Writer |
|---|---|---|---|
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) | Always, every session | Org admin |
| Project root | `./CLAUDE.md` or `./.claude/CLAUDE.md` | At launch, walks up tree | You (committed) |
| Path-scoped rules | `.claude/rules/*.md` (with `paths:` frontmatter) | When matching files are read; or always if no `paths:` | You (committed) |
| Project local | `./CLAUDE.local.md` | At launch, alongside CLAUDE.md | You (gitignored) |
| User global | `~/.claude/CLAUDE.md` | Every session, any project | You (machine-wide) |
| User rules | `~/.claude/rules/*.md` | Every session (path-scoped optional) | You (machine-wide) |
| Auto memory | `~/.claude/projects/<proj>/memory/MEMORY.md` + topic files | First 200 lines / 25KB of MEMORY.md at launch; topic files on demand | **Claude** |
| AGENTS.md | `./AGENTS.md` | Only via `@AGENTS.md` import in CLAUDE.md | You |

See [references/routing.md](references/routing.md) for the routing decision tree (which surface for what kind of content).

## Workflow

### Phase 1: Discovery

Run all of these. Use the live results, not the first match.

```bash
# Project surfaces (walks current tree)
fd -uHI -e md -t f '^(CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md)$' .
fd -uHI -e md . .claude/rules 2>/dev/null

# User surfaces
ls ~/.claude/CLAUDE.md 2>/dev/null
fd -uHI -e md . ~/.claude/rules 2>/dev/null

# Managed policy (macOS path; check Linux/Windows equivalents if relevant)
ls "/Library/Application Support/ClaudeCode/CLAUDE.md" 2>/dev/null

# Auto memory directory for this project
# Path is ~/.claude/projects/<derived-from-git-repo>/memory/
ls ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null
```

Don't truncate output. If `fd` isn't installed, fall back to `find`. Never skip the user-level surfaces — content placed at user scope can override or duplicate project scope and is the most common cross-surface conflict source.

### Phase 2: Categorical Findings

For each file, scan for these specific findings rather than scoring on a numeric rubric. See [references/quality-criteria.md](references/quality-criteria.md) for detection details, severity, and example fixes.

| Finding | What it means |
|---|---|
| **misplaced** | Content lives on wrong surface (e.g. path-scoped rule in CLAUDE.md, multi-step workflow that should be a skill, conversational learning manually written instead of letting auto memory handle it) |
| **oversized** | CLAUDE.md exceeds ~200 lines (doc target); reduces adherence and consumes context |
| **stale** | Commands that would fail, references to deleted files, outdated tech versions |
| **duplicated** | Same instruction appears across multiple surfaces (root + subdir CLAUDE.md, CLAUDE.md + auto memory, CLAUDE.md + skill) |
| **conflicting** | Two surfaces give contradictory instructions for the same behavior |
| **misnamed** | Wrong filename — `.claude.local.md` (legacy/incorrect) instead of `CLAUDE.local.md`; `claude.md` instead of `CLAUDE.md` |
| **unscoped** | Path-specific content in `.claude/rules/*.md` is missing the `paths:` frontmatter so it loads unconditionally |
| **missing-import** | Project has `AGENTS.md` but no `@AGENTS.md` import in CLAUDE.md (causes drift between agents) |
| **drifted** | CLAUDE.md describes structure/commands that no longer match the codebase |

### Phase 3: Routing recommendations

For each finding, propose a target surface using the decision tree in [references/routing.md](references/routing.md). The most common useful moves:

- Section in CLAUDE.md that only matters for `src/api/**` → extract to `.claude/rules/api.md` with `paths: ["src/api/**"]` frontmatter
- Multi-step workflow in CLAUDE.md → extract to a skill (the body still loads from CLAUDE.md every session, wasting context; a skill loads on demand)
- Personal preference shared in team CLAUDE.md → move to `~/.claude/CLAUDE.md` or `CLAUDE.local.md`
- "I always have to remind Claude X" learning → leave it; auto memory will capture it. If it's already in CLAUDE.md and ALSO in auto memory, deduplicate (prefer CLAUDE.md for things you author, auto memory for things Claude noticed).
- Repository has `AGENTS.md` but no import → add `@AGENTS.md` to CLAUDE.md.

### Phase 4: Quality Report

Output BEFORE making any changes. Format:

```
## CLAUDE.md / Memory Audit

### Surface inventory
- Project root CLAUDE.md: <path> (<line count>)
- .claude/rules/: <N files>
- CLAUDE.local.md: <present|absent>
- User CLAUDE.md: <path> (<line count>)
- AGENTS.md: <present|absent, imported=yes|no>
- Auto memory: <path> (MEMORY.md <line count>, <N topic files>)

### Findings
For each file, list categorical findings with severity. Group by file.

#### ./CLAUDE.md
- [oversized] 312 lines (target ≤200) — recommend decomposition
- [misplaced] "API conventions" section (lines 88-140) is path-scoped to src/api/ — extract to .claude/rules/api.md
- [misnamed] References .claude.local.md in line 12; correct filename is CLAUDE.local.md
- [missing-import] AGENTS.md exists at ./AGENTS.md but is not imported

#### .claude/rules/security.md
- [unscoped] No `paths:` frontmatter; loads on every session even though content only relevant to auth code
```

### Phase 5: Targeted updates

After report and user approval, apply fixes one finding at a time:

- Show a diff for each
- For **misplaced** findings that need a new file, show both: the new file content AND the deletion from the original
- For **oversized**, recommend `/decompose-claude-md` rather than guessing the split inline — it's a multi-step refactor that deserves its own focused command
- Never write to `~/.claude/projects/<proj>/memory/` — that's Claude's surface. Only flag duplication.

See [references/update-guidelines.md](references/update-guidelines.md) for what content earns its place on each surface.

### Phase 6: Decomposition handoff

If any CLAUDE.md is **oversized** or has 3+ **misplaced** findings, recommend the user invoke `/decompose-claude-md <path>` afterward. That command does a clean section-by-section refactor pass that's hard to do safely inline within an audit. See [references/decomposition-heuristics.md](references/decomposition-heuristics.md) for what triggers the recommendation.

## Templates

See [references/templates.md](references/templates.md) for current templates: project root, `.claude/rules/<topic>.md` with frontmatter, user-level CLAUDE.md, AGENTS.md import pattern, monorepo with `claudeMdExcludes`.

## What changed vs the legacy plugin

This skill replaces the upstream `claude-md-improver`. Key differences in [SOURCES.md](SOURCES.md). Short version: routes across all surfaces (not just CLAUDE.md), fixes the `.claude.local.md` filename bug, drops the numeric rubric for actionable categorical findings, and pairs with `/decompose-claude-md` for the refactor follow-through.

## Debugging memory loading

If the user's findings don't match what they expect Claude to see, the `InstructionsLoaded` hook (https://code.claude.com/docs/en/hooks.md) logs exactly which instruction files load and when. Suggest it for hard-to-diagnose load-order or path-scoped-rule issues.

`/memory` (built-in) is the user's interactive view of what's loaded right now — point them there for a sanity check.

## Tips to share with the user

- Ask Claude to "remember X" → goes to auto memory. To put it in CLAUDE.md instead, say "add this to CLAUDE.md".
- Block-level HTML comments in CLAUDE.md are stripped before injection — useful for maintainer notes (like source links) without spending tokens.
- For monorepos, `claudeMdExcludes` in `.claude/settings.local.json` skips other teams' CLAUDE.md files from the directory walk.
- `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ../shared` loads memory from extra directories.
