# Quality criteria — categorical findings

<!--
Source: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04

Categorical findings rather than a numeric rubric — numeric scores invite
rubric-gaming and don't drive useful actions, while each categorical
finding points at a specific fix.
-->

For each memory file in scope, scan for these findings. Each has a definition, detection method, severity, and suggested fix.

## Findings

### `misplaced` — content lives on the wrong surface

**Severity:** High (most common, biggest leverage)

**Detect:**
- A section in CLAUDE.md mentions only paths under a single directory → should be `.claude/rules/<dir>.md` with `paths:` frontmatter
- A section is a multi-step procedure (numbered steps, "first/then/finally") → should be a skill
- A section is gitignored-personal content (sandbox URL, test creds, personal pref) sitting in committed CLAUDE.md → should be `CLAUDE.local.md` or `~/.claude/CLAUDE.md`
- Auto memory (`MEMORY.md`) contains user-authored explicit rules instead of Claude-discovered learnings → should be CLAUDE.md
- CLAUDE.md duplicates content from `AGENTS.md` instead of importing it

**Fix:** Move the content to the correct surface using [routing.md](routing.md). Show both the new file content and the deletion from the old file.

### `oversized` — CLAUDE.md exceeds 200 lines

**Severity:** Medium-High

**Detect:** `wc -l` on each CLAUDE.md / CLAUDE.local.md. The doc target is "under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."

**Fix:** Recommend `/decompose-claude-md <path>`. The decomposition heuristics (see [decomposition-heuristics.md](decomposition-heuristics.md)) drive the split.

### `stale` — content describes state that no longer exists

**Severity:** High (actively misleads Claude)

**Detect:**
- Documented commands that fail when run (or when their referenced scripts/files don't exist)
- Path references to deleted directories or files
- Tech versions that don't match `package.json` / `Cargo.toml` / etc.
- "TODO" markers that have outlived their context

**Fix:** Update or delete. Verify before deleting (the user may know why it's there).

### `duplicated` — same instruction on multiple surfaces

**Severity:** Medium

**Detect:**
- `rg --no-heading -n` for distinctive phrases across all surfaces
- Pay extra attention to root-CLAUDE.md vs subdirectory-CLAUDE.md (the walk-up loader concatenates both)
- CLAUDE.md content also appearing in auto memory's MEMORY.md

**Fix:** Keep one copy on the most-scoped surface. Cross-surface duplication wastes context and risks drift.

### `conflicting` — two surfaces disagree

**Severity:** High

**Detect:** Cross-reference instructions about the same topic across surfaces. Look especially at:
- Project CLAUDE.md vs user CLAUDE.md (user-level might say "use 4-space" while project says "use 2-space")
- CLAUDE.md vs `.claude/rules/*.md` (rules might override project settings without intending to)
- AGENTS.md vs CLAUDE.md content not under the import

**Fix:** Resolve with the user. The doc warns: "if two rules contradict each other, Claude may pick one arbitrarily."

### `misnamed` — wrong filename

**Severity:** High (file is being silently ignored)

**Detect:**
- `.claude.local.md` (legacy/incorrect — Claude does not read this filename)
- `claude.md` (lowercase — Claude does not read this filename)
- References inside CLAUDE.md to incorrect filenames

**Fix:** Rename to the correct filename. Real names are `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`. Update any internal references.

### `unscoped` — `.claude/rules/*.md` missing path scoping

**Severity:** Low-Medium

**Detect:** Rule file in `.claude/rules/` whose content clearly references only one directory or filetype, but lacks `paths:` frontmatter. Loads on every session unnecessarily.

**Fix:** Add a `paths:` frontmatter block with appropriate glob patterns.

### `missing-import` — AGENTS.md exists but isn't imported

**Severity:** Medium

**Detect:** `AGENTS.md` exists at project root but no `@AGENTS.md` line appears in CLAUDE.md.

**Fix:** Add `@AGENTS.md` near the top of CLAUDE.md so both Claude Code and other agents read the same instructions. If the content is currently duplicated in CLAUDE.md, delete the duplicate after the import.

### `drifted` — content describes structure that no longer matches the codebase

**Severity:** Medium

**Detect:** Cross-reference architecture/file-layout descriptions in CLAUDE.md against `eza --tree --git-ignore -L 2` (or similar). Look for moved/renamed/deleted directories.

**Fix:** Update the architecture section. If this drifts often, that section is probably better as a `.claude/rules/architecture.md` file the auditor flags more aggressively.

### `unimported-companion` — companion file exists but isn't imported

**Severity:** Low

**Detect:** Files like `package.json`, `README.md`, `docs/git-instructions.md` referenced in chat or commit history but never `@`-imported in CLAUDE.md when they would help.

**Fix:** Suggest `@path/to/file` import. Note the doc warning: imported files load in full at session start, so prefer imports for files Claude legitimately needs every session.

## Severity legend

- **High** — actively misleads Claude or wastes significant context. Fix promptly.
- **Medium** — meaningful drift but not blocking. Schedule a fix.
- **Low** — polish; surface in audit but don't block on it.

## Output format

In the audit report, list findings under each file like:

```
#### ./CLAUDE.md  (312 lines)
- [oversized] 312 lines exceeds 200-line target → /decompose-claude-md
- [misplaced] Lines 88-140 "API conventions" only references src/api/** → extract to .claude/rules/api.md
- [misnamed] Line 12 references .claude.local.md → CLAUDE.local.md
- [stale] Line 47 `npm run dev` script not in package.json
```
