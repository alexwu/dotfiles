---
name: claude-md-improver
description: Audit and improve Claude Code memory surfaces — CLAUDE.md, .claude/rules/, CLAUDE.local.md, user-level files, and auto-memory hygiene. Use when the user asks to check, audit, update, improve, fix, refresh, or re-route their CLAUDE.md, project memory, .claude/rules/, or notes that their CLAUDE.md is out of date or growing too large. Also use when they mention CLAUDE.md maintenance, memory routing, or want to know whether a learning belongs in CLAUDE.md vs .claude/rules/ vs auto memory vs a skill. Also covers scouring the repo and recent git history for new features, commands, or conventions that should be documented but aren't.
tools: Read, Glob, Grep, Bash, Edit, Agent
---

<!--
Source: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04
See SOURCES.md for re-sync pointers if Claude Code memory features change.
-->

# CLAUDE.md Improver

Audit, route, and improve Claude Code memory surfaces. The job has two halves, and both are necessary:

1. **Subtractive** — flag what's misplaced, oversized, stale, duplicated, conflicting, misnamed, unscoped, drifted.
2. **Additive** — scour the repo and recent git history for features, commands, conventions, and gotchas that *should* be in memory but aren't.

Most "my CLAUDE.md is messy" complaints are actually one of these. An audit that only does the subtractive half misses everything the user built since the last refresh.

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

Enumerate every memory surface. Run all of these — use the live results, not the first match.

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

### Phase 2: Repo scour (additive)

This is the half that subtractive-only audits miss. Goal: find features, commands, conventions, gotchas, and architecture that exist in the repo but are absent from (or stale in) memory files.

**Read [references/update-guidelines.md](references/update-guidelines.md) before this phase.** It defines what earns a place on each memory surface and what to skip. The scour subagents need this rubric to decide what to flag — without it they will over-collect (every new file becomes an "addition") or under-collect (real new features get filtered as "obvious from the code").

#### Determine the commit range

| Source | How |
|---|---|
| **Default** | Since CLAUDE.md was last meaningfully touched. `baseline=$(git log -1 --format=%H -- CLAUDE.md .claude/CLAUDE.md 2>/dev/null); git log "${baseline}..HEAD" --oneline` |
| **User says "PR #N"** | `gh pr view <N> --json baseRefName,headRefOid -q '.baseRefName + "..." + .headRefOid'` then `git log <range> --oneline` |
| **User specifies a branch** | `git log main..feature/x --oneline` (or whatever they named) |
| **User specifies an explicit range** | `git log abc123..def456 --oneline` |
| **No git history available** (brand new repo, or static snapshot audit) | Skip the range; scour the current tree directly |

If the user wants something specific, honor it. The default only applies when they ask for a generic audit.

#### Partition into subagent slices

Count the commits in scope. If **more than 30**, partition into chunks of ~20-30 commits and fan out one `code-explorer` subagent per chunk. At or below 30, a single subagent walks the whole range.

Each scour subagent receives:

- Its assigned commit range (e.g. `git log abc123..def456 --stat -p`)
- Current contents of every CLAUDE.md and `.claude/rules/*.md` discovered in Phase 1
- The full text of [references/update-guidelines.md](references/update-guidelines.md)

Each subagent returns three lists:

| Category | Meaning |
|---|---|
| **addition** | Something in code (new module, command, hook, config, convention) that isn't in memory but earns its place per update-guidelines.md |
| **drift** | Memory content that no longer matches the code — paths moved, commands changed, structure rearranged |
| **demoted** | Memory content whose code reason has gone away (deleted modules, retired workflows) |

#### Scour subagent prompt template

Every scour subagent gets the same shape of task. Use this template when invoking each `code-explorer`:

```
TASK: Scour a git commit range for memory-file additions, drift, and demotions.

COMMIT RANGE: <e.g. abc123..def456>
WORKING DIRECTORY: <repo root>

CURRENT MEMORY FILE CONTENTS:
<inline the contents of CLAUDE.md, .claude/CLAUDE.md, and every .claude/rules/*.md>

UPDATE RUBRIC: <inline the full text of references/update-guidelines.md>

PROCEDURE:
1. Run `git log <range> --stat -p` and read the full output. Do not truncate.
2. For each meaningful change, classify per the rubric:
   - ADDITION  — new code reality that earns its place but isn't in any memory file
   - DRIFT     — memory content that no longer matches code reality
   - DEMOTED   — memory content whose code reason has gone away
3. Apply the rubric's "What NOT to add" filter aggressively. Skip:
   - Things obvious from the code (e.g. "the UserService class handles users")
   - Generic best practices ("write tests")
   - One-off bug fixes
   - Verbose explanations

OUTPUT (one entry per finding, in this exact format so aggregation works):

### [addition|drift|demoted] <one-line title>
- **Evidence:** <commit hashes and/or file paths>
- **Why it matters:** <one-line; what future sessions gain or lose>
- **Proposed surface:** <CLAUDE.md | .claude/rules/<file>.md | CLAUDE.local.md | skill | none>
- **Diff sketch:** <2-5 lines showing the proposed add/edit/remove>

If your slice has no findings, return exactly: "No findings in this range."
```

The output format matters — the main agent's aggregation step parses these blocks. Drifting from the format produces silently-dropped findings.

#### Aggregate

Main agent collects results from all slices, deduplicates overlap (the same feature added in commit A and refined in commit C should produce one finding, not two), and feeds the merged lists into Phase 4.

For static-snapshot mode (no commit range), run a single `code-explorer` subagent against the *current* tree, comparing against memory files using the same three categories.

### Phase 3: Categorical findings (subtractive)

For each memory file, scan for the following findings. See [references/quality-criteria.md](references/quality-criteria.md) for detection details, severity, and example fixes.

**Parallelize when 4+ memory files are in scope.** Fan out one `code-explorer` subagent per file; each gets the file's contents and the text of quality-criteria.md, returns its finding list. With 1-3 files, run inline.

#### Per-file audit subagent prompt template

```
TASK: Audit a single memory file against the categorical findings rubric.

FILE PATH: <e.g. ./CLAUDE.md>
FILE CONTENTS:
<inline the file contents>

CRITERIA: <inline the full text of references/quality-criteria.md>

PROCEDURE:
1. Read the file in full.
2. For each finding type in the rubric, scan for matches.
3. Cross-check stale/drifted findings against the actual codebase
   (read referenced files, run referenced commands if safe).

OUTPUT (one entry per finding, in this exact format):

### [<finding-type>] <one-line title>
- **Severity:** <high|medium|low>
- **Lines:** <line range, e.g. L88-L140>
- **Evidence:** <short quoted excerpt or path that triggered this>
- **Suggested fix:** <one line>

If the file is clean, return exactly: "No findings."
```

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

`drifted` findings can come from either Phase 2 (history-aware) or Phase 3 (current-state). Deduplicate when both surface the same item.

### Phase 4: Routing

For each item from Phases 2 and 3, propose a target surface using the decision tree in [references/routing.md](references/routing.md). Common useful moves:

- Section in CLAUDE.md that only matters for `src/api/**` → extract to `.claude/rules/api.md` with `paths: ["src/api/**"]` frontmatter
- Multi-step workflow in CLAUDE.md → extract to a skill (the body still loads from CLAUDE.md every session, wasting context; a skill loads on demand)
- Personal preference shared in team CLAUDE.md → move to `~/.claude/CLAUDE.md` or `CLAUDE.local.md`
- New repo feature surfaced in scour → most often CLAUDE.md (project-wide) or `.claude/rules/<topic>.md` (path-scoped)
- "I always have to remind Claude X" learning → leave it; auto memory will capture it. If it's already in CLAUDE.md and ALSO in auto memory, deduplicate (prefer CLAUDE.md for things you author, auto memory for things Claude noticed).
- Repository has `AGENTS.md` but no import → add `@AGENTS.md` to CLAUDE.md.

### Phase 5: Quality report

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

### Scour scope
- Commit range: <baseline..HEAD or user-specified>
- Commits walked: <N>
- Subagent slices: <K> (or "single agent, below threshold")

### Additions / drift / demoted (from Phase 2)

Examples of each (collapse to bullet form in the actual report):

#### [addition] persona_anchor.nim hook
- **Evidence:** `scripts/claude/persona_anchor.nim` added in commits a1b2c3d..e4f5g6h
- **Why:** Hook re-injects compressed CLAUDE.md recap; nobody adding hooks would know to follow this pattern without docs
- **Proposed surface:** `./CLAUDE.md` (project-wide; affects all hook work in this repo)
- **Diff sketch:** add bullet under `## Hooks` listing the file, knobs, state path

#### [drift] CLAUDE.md commands table
- **Evidence:** CLAUDE.md L34 says `pnpm dev` but `package.json` script is now `pnpm start:dev`
- **Why:** Stale command actively misleads
- **Proposed surface:** `./CLAUDE.md` (in-place edit)
- **Diff sketch:** `- pnpm dev` → `+ pnpm start:dev`

#### [demoted] Legacy auth section
- **Evidence:** CLAUDE.md L120-148 describes `src/legacy_auth/`; directory deleted in commit `f00d`
- **Why:** Section refers to nothing; pure context waste
- **Proposed surface:** none (deletion)
- **Diff sketch:** remove L120-148

### Findings (from Phase 3)
For each file, list categorical findings with severity. Group by file.

#### ./CLAUDE.md
- [oversized] 312 lines (target ≤200) — recommend decomposition
- [misplaced] "API conventions" section (lines 88-140) is path-scoped to src/api/ — extract to .claude/rules/api.md
- [misnamed] References .claude.local.md in line 12; correct filename is CLAUDE.local.md
- [missing-import] AGENTS.md exists at ./AGENTS.md but is not imported

#### .claude/rules/security.md
- [unscoped] No `paths:` frontmatter; loads on every session even though content only relevant to auth code
```

### Phase 6: Targeted updates

After report and user approval, apply fixes one item at a time.

**Read [references/update-guidelines.md](references/update-guidelines.md) at the top of this phase.** Even though the Phase 2 subagents loaded it, the main agent doing the editing needs the same rubric in front of it — the "what to add / what NOT to add / capture format" sections drive the diffs you produce here. Skipping this re-read is the failure mode that produces additions like "The UserService class handles user operations" — exactly what the rubric forbids.

For each item:

- Show a diff before applying
- For **misplaced** items that need a new file, show both: the new file content AND the deletion from the original
- For **addition** items, follow the `Capture format per addition` block in update-guidelines.md (Why / Surface choice / diff)
- For **oversized**, recommend `/decompose-claude-md` rather than guessing the split inline — it's a multi-step refactor that deserves its own focused command
- Never write to `~/.claude/projects/<proj>/memory/` — that's Claude's surface. Only flag duplication.

### Phase 7: Decomposition handoff

If any CLAUDE.md is **oversized** or has 3+ **misplaced** findings, recommend the user invoke `/decompose-claude-md <path>` afterward. That command does a clean section-by-section refactor pass that's hard to do safely inline within an audit. See [references/decomposition-heuristics.md](references/decomposition-heuristics.md) for what triggers the recommendation.

## Templates

See [references/templates.md](references/templates.md) for current templates: project root, `.claude/rules/<topic>.md` with frontmatter, user-level CLAUDE.md, AGENTS.md import pattern, monorepo with `claudeMdExcludes`.

## Debugging memory loading

If the user's findings don't match what they expect Claude to see, the `InstructionsLoaded` hook (https://code.claude.com/docs/en/hooks.md) logs exactly which instruction files load and when. Suggest it for hard-to-diagnose load-order or path-scoped-rule issues.

`/memory` (built-in) is the user's interactive view of what's loaded right now — point them there for a sanity check.

## Tips to share with the user

- Ask Claude to "remember X" → goes to auto memory. To put it in CLAUDE.md instead, say "add this to CLAUDE.md".
- Block-level HTML comments in CLAUDE.md are stripped before injection — useful for maintainer notes (like source links) without spending tokens.
- For monorepos, `claudeMdExcludes` in `.claude/settings.local.json` skips other teams' CLAUDE.md files from the directory walk.
- `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ../shared` loads memory from extra directories.
