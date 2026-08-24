---
name: decompose-claude-md
description: Refactor an oversized CLAUDE.md by extracting sections into path-scoped .claude/rules/ files, or split an oversized AGENTS.md spatially into nested per-directory AGENTS.md files. Use when a CLAUDE.md or AGENTS.md has grown too long, when the user calls it bloated, unwieldy, over 200 lines, or says it's eating context, or asks to decompose, split, break up, slim down, extract from, or reorganize their project memory file. Also use when a claude-md-improver audit reports an `oversized` finding or 3+ `misplaced` findings and the user wants the refactor actually performed.
---

<!--
Source doc: https://code.claude.com/docs/en/memory.md
Sibling skill (provides the rubrics this skill consults at runtime):
  claude-md-improver
AGENTS.md spec (nested-files model; no import/include syntax, no rules dir):
  https://agents.md/
  https://developers.openai.com/codex/guides/agents-md
Last synced: 2026-05-04
-->

# Decompose CLAUDE.md

Decompose a CLAUDE.md that's grown too large by extracting sections into `.claude/rules/` files. Pairs with the `claude-md-improver` skill (which flags candidates) — this skill is the actual refactor.

Target: project root CLAUDE.md drops to ≤80 lines and serves as an index; long sections live in path-scoped rules.

**Two modes.** Many repos keep their real instructions in an `AGENTS.md` (the cross-agent convention) and expose only a thin `CLAUDE.md` that `@AGENTS.md`-imports it. Detect this in Step 1.5 and branch: **CLAUDE.md mode** (extract → `.claude/rules/`, the default) or **AGENTS.md mode** (split → nested per-directory `AGENTS.md` files). The two are not interchangeable — AGENTS.md content must never land in `.claude/rules/` (Claude-only; every other agent would lose it).

## Sibling rubrics

Steps 3 and 5 read rubrics out of the `claude-md-improver` skill, which installs alongside this one. Resolve its root before you need it — the path differs by host:

```bash
for r in ~/.claude/skills ~/.agents/skills .claude/skills; do
  [ -d "$r/claude-md-improver" ] && echo "$r/claude-md-improver"
done
```

If it isn't installed anywhere, say so and work from the inline tables below — they're a summary of those rubrics, not a replacement for them.

## User-scope guard

`~/.claude/CLAUDE.md` and `~/.claude/rules/*.md` load into **every project on the machine**. This skill may propose moving content there and must never perform it. Report the extraction with its diff, then leave it — the user opts in per session, and silence is not opt-in. Same rule as `claude-md-improver` Phase 6.

## Step 1: Resolve and read the target

Skills get no `$ARGUMENTS` substitution — take the target from the conversation:

| Situation | Target |
|---|---|
| The user named a path | Use it verbatim |
| The user said "my CLAUDE.md" or gave no path | `./CLAUDE.md` |
| No `./CLAUDE.md`, but `./.claude/CLAUDE.md` exists | Use that |
| Several candidates and no signal (monorepo, nested CLAUDE.md files) | List what you found with line counts and ask which one — don't pick for them |

```bash
fd -uHI -e md -t f '^(CLAUDE\.md|AGENTS\.md)$' .
wc -l "$TARGET"
```

Then `Read` the full file. Don't truncate.

## Step 1.5: Identify the source of truth

Before measuring anything, figure out *which file actually holds the instructions*. A thin `CLAUDE.md` that only imports `AGENTS.md` is not a small file with nothing to do — its content lives in AGENTS.md, which decomposes by different rules.

```bash
# Does the target just import AGENTS.md? (thin-shell pattern)
rg -n '^@AGENTS\.md' "$TARGET"
# Is there an AGENTS.md at the project root, and how big is it?
[ -f ./AGENTS.md ] && wc -l ./AGENTS.md
```

Pick the mode:

| Situation | Mode |
|---|---|
| `TARGET` is a normal CLAUDE.md carrying its own content | **CLAUDE.md mode** — continue to Step 2 |
| `TARGET` is a thin shell whose only real line is `@AGENTS.md` (the bulk lives in AGENTS.md), **or** `TARGET` is itself an `AGENTS.md` | **AGENTS.md mode** — jump to the "AGENTS.md mode" section below; skip Steps 2–6 |

Do **not** dismiss a thin `@AGENTS.md` CLAUDE.md as "too small, nothing to do." The content isn't missing — redirect to AGENTS.md mode.

In CLAUDE.md mode only: if the target is under 200 lines and fewer than 5 H2 sections, push back: "This file is X lines / N sections — decomposition probably isn't worth it. Want to proceed anyway?"

## Step 2: Section inventory

For each H2 (`## ...`) section, record:

| Field | How to determine |
|---|---|
| `title` | The H2 text |
| `lines` | Line range and count |
| `path_scope` | Directories/filetypes the section's content references — if all references fall under one dir, it's path-scopable |
| `procedure_shape` | Yes/no — has numbered steps, "first/then/finally", branching |
| `topic` | One-word topic for naming the rule file |

Output as a table before proposing a split.

## Step 3: Classify each section

**Read `<sibling>/references/decomposition-heuristics.md` before classifying** (resolve `<sibling>` per "Sibling rubrics" above). It's the canonical rubric — what stays at root, what extracts to `.claude/rules/`, what becomes a skill, plus glob heuristics for `paths:` frontmatter. Skipping this read produces classifications that drift from the audit skill's expectations, which means the next `claude-md-improver` audit re-flags everything you just moved.

For each section, pick a fate per that rubric:

| Fate | When |
|---|---|
| **Stay** | Project description, top-level command table, ≤30-line architecture, index of rule files, imports |
| **Extract → `.claude/rules/<topic>.md` (scoped)** | Path-scoped content that only matters under one dir/filetype |
| **Extract → `.claude/rules/<topic>.md` (unscoped)** | Cross-cutting but long enough to own a file (style guides, testing conventions) |
| **Extract → skill** | Multi-step procedure |
| **Extract → `CLAUDE.local.md`** | Personal/machine-specific content currently in committed CLAUDE.md |
| **Extract → `~/.claude/CLAUDE.md` — propose-only** | Cross-project preferences misfiled here. Show the extraction in the plan and mark it not-applied; see "User-scope guard" |
| **Drop** | Stale, duplicated, obvious — flag for deletion, don't move |

## Step 4: Propose the split

Show the user a plan before writing anything. Format:

```
## Decomposition plan for <path>

Current: <line count> lines, <section count> H2 sections.
Target: ≤80 lines (root) + N rule files.

### Sections

| Section | Lines | Fate | Destination |
|---|---|---|---|
| Commands | 5–25 | Stay | (root) |
| API conventions | 88–140 | Extract scoped | .claude/rules/api.md (`paths: ["src/api/**"]`) |
| Testing | 145–180 | Extract scoped | .claude/rules/testing.md (`paths: ["**/*.test.ts", "tests/**"]`) |
| Sandbox URLs | 200–215 | Extract personal | CLAUDE.local.md |
| How to add a feature | 220–260 | Extract → skill | .claude/skills/add-feature/ |

### New root CLAUDE.md outline

(<approximate post-decomposition structure>)

### New files to create

- .claude/rules/api.md (~52 lines)
- .claude/rules/testing.md (~35 lines)
- CLAUDE.local.md (~15 lines)
- .claude/skills/add-feature/SKILL.md (stub)

### .gitignore changes

- Add CLAUDE.local.md to .gitignore (if not already)

### Proposed but NOT applied (user scope)

- 3 lines of cross-project preference → ~/.claude/CLAUDE.md — say the word and I'll move them
```

Omit the user-scope block when nothing routes there.

## Step 5: Confirm and apply

Wait for approval.

**Before writing anything, read `<sibling>/references/templates.md`.** It has the canonical shapes for path-scoped rule files, unscoped rule files, `CLAUDE.local.md`, the `@AGENTS.md` import pattern, and the project-root post-decomposition layout. Improvising frontmatter or rule structure produces inconsistencies between this skill's output and the audit skill's expectations — and YAML frontmatter is unforgiving about quoting, list syntax, and indentation, so working from a template avoids silent parse failures.

On approval:

1. Create `.claude/rules/` if it doesn't exist
2. Write each new rule file with appropriate frontmatter (`paths:` if scoped) per templates.md
3. Write `CLAUDE.local.md` if any extractions need it; check `.gitignore` and add an entry if missing
4. Stub each skill with a minimal `SKILL.md` — keep the original section content untouched and let the user refactor it into a real skill workflow later. Don't fabricate steps the section didn't have. Stub shape:

   ````markdown
   ---
   name: <skill-slug>
   description: <one-line trigger taken from the original CLAUDE.md section heading and intent>
   ---

   <!-- Stubbed by the decompose-claude-md skill on YYYY-MM-DD from <source CLAUDE.md path>, section "<title>" (lines X-Y).
        Original content is preserved below verbatim — refactor into a proper skill workflow when ready. -->

   # <Original section title>

   <Original section body, copied verbatim.>
   ````

5. Rewrite the root CLAUDE.md with: imports at top → project description → command table → architecture overview → rules index table → top-level gotchas only
6. Run `wc -l` on the new root file and confirm it's under target

Skip any user-scope destination. Restate it as still-pending in the summary.

For the rules index table in the new root CLAUDE.md, format:

```markdown
Reference docs are split across `.claude/rules/`:

| File | Covers |
|------|--------|
| `api.md` | API endpoint conventions (path-scoped) |
| `testing.md` | Test commands and patterns (path-scoped) |
```

## Step 6: Verify

After apply:

- `wc -l` each touched file
- `Read` each new rule file back. Confirm:
  - Frontmatter delimiters are `---` on their own lines (not indented, not replaced by `'''` or other)
  - `paths:` is a YAML list, each entry quoted, each glob well-formed (no stray spaces, balanced braces)
  - No accidental code-fence damage from the extraction (an unclosed ` ``` ` swallows the rest of the file)
- `Grep` for any references that still point to the old line numbers/sections (e.g. `see "API conventions" above`) and fix them to point at the new file
- Check that no content was lost — every line either stays at root, moves to a new file, or is explicitly dropped

Report a one-line summary: "Decomposed CLAUDE.md from N→M lines, extracted X rule files (Y scoped, Z unscoped), W skill stubs, and moved K personal lines to CLAUDE.local.md." Name any user-scope extractions left pending.

## AGENTS.md mode

`AGENTS.md` is the cross-agent instructions convention — read by Codex, Cursor, Aider, and by Claude Code via an `@AGENTS.md` import. It does **not** decompose the way CLAUDE.md does, because the spec is built on different mechanics:

- **No import / include syntax.** There is no `@path` directive in AGENTS.md — `@import` is Claude-Code-specific. Other agents read AGENTS.md raw and would never follow it.
- **No rules directory.** There is no `.agents/rules/` analog to `.claude/rules/`.
- **The only native split is spatial:** nested `AGENTS.md` files, one per directory. Agents walk from the repo root down to the working directory, concatenate each `AGENTS.md` they pass (one per directory), and the **closest file wins** on conflicts. (Codex stops loading once the combined size hits `project_doc_max_bytes` — 32 KiB by default.)

### Hard guard — never do this

**Do NOT extract AGENTS.md content into `.claude/rules/`.** Those files load for Claude Code *only*; every other agent reading AGENTS.md would silently lose the content, breaking the entire point of a shared source of truth. `.claude/rules/` is exclusively a CLAUDE.md-mode target. If you catch yourself proposing a `.claude/rules/<topic>.md` while in AGENTS.md mode, stop.

### How to decompose an AGENTS.md

Decomposition here is *spatial*, not modular. For each H2 section, ask: **does this only matter inside one directory/subtree?**

| Section character | Fate |
|---|---|
| Directory-scoped (a package's build dance, conventions specific to one crate/module) | Move to `<that-dir>/AGENTS.md`. Closest-wins makes it override root guidance for that subtree. |
| Cross-cutting / global (architecture overview, repo-wide invariants, commit conventions) | **Stays in the root `AGENTS.md`.** There is no global-but-fragmented option — global content has nowhere else to live. |

A root AGENTS.md that's mostly cross-cutting laws therefore **can't meaningfully shrink** — and that's correct, not a failure. Only pull a section into a nested file when its content genuinely belongs to that directory.

### When AGENTS.md mode is a no-op

If the AGENTS.md is (a) comfortably under the 32 KiB cap / ~200 lines, or (b) mostly global content with little that's directory-scopable, say so and stop. Don't manufacture nested files to hit a line target — scattering global laws across directories makes them *harder* to find, not easier.

### Apply

Same discipline as CLAUDE.md mode: show the plan (which sections move to which `<dir>/AGENTS.md`, which stay at root) and get approval before writing. Preserve the root `# <title>` heading and any maintainer comments. After applying, confirm no content was lost — every moved section lands in exactly one nested file, and the root still reads coherently with the directory-specific parts removed.

## Pitfalls to avoid

- **Don't lose content silently.** Every removed line from the root must land somewhere or be explicitly dropped with the user's sign-off.
- **Don't aggressively scope.** If you're guessing at the `paths:` glob, leave the rule unscoped — better to load slightly more than needed than to silently miss context.
- **Don't fabricate skill bodies.** If a section was a procedure, extract it as a skill stub with the original section content; don't try to flesh it into a "proper" skill in this pass.
- **Don't decompose what's already small.** Push back when called on a tidy CLAUDE.md.
- **Preserve maintainer comments.** HTML comments at the top of CLAUDE.md (source pointers, last-synced dates) stay at root.
- **Don't shred AGENTS.md into `.claude/rules/`.** That surface is Claude-Code-only; other agents reading AGENTS.md would lose the content silently. AGENTS.md decomposes spatially into nested per-directory files (see "AGENTS.md mode"), never into rules.
- **Don't write to user scope.** See "User-scope guard" — propose, report, stop.

## Notes for the agent

- This skill is destructive in the sense that it rewrites CLAUDE.md. Show the full plan before any writes. Get approval per the user's standard "confirm destructive actions" rule.
- If invoked from inside a `claude-md-improver` audit, you can carry forward the section inventory the audit produced — no need to re-discover.
