---
description: Refactor an oversized CLAUDE.md by extracting sections into .claude/rules/ files (with paths: scoping where appropriate)
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
argument-hint: <path-to-CLAUDE.md> (defaults to ./CLAUDE.md)
---

<!--
Source doc: https://code.claude.com/docs/en/memory.md
Sibling skill (provides the rubrics this command consults at runtime):
  ~/.claude/skills/claude-md-improver/
Last synced: 2026-05-04
-->

Decompose a CLAUDE.md that's grown too large by extracting sections into `.claude/rules/` files. Pairs with the `claude-md-improver` skill (which flags candidates) — this command is the actual refactor.

Target: project root CLAUDE.md drops to ≤80 lines and serves as an index; long sections live in path-scoped rules.

## Argument

`$ARGUMENTS` should be a path to a CLAUDE.md file. If empty, default to `./CLAUDE.md`.

## Step 1: Read the target

`$ARGUMENTS` is substituted as literal text by the slash command runner, so the usual `${VAR:-default}` shell expansion doesn't apply. Branch on emptiness explicitly:

```bash
TARGET="$ARGUMENTS"
[ -z "$TARGET" ] && TARGET="./CLAUDE.md"
wc -l "$TARGET"
```

Then `Read` the full file. Don't truncate.

If under 200 lines and fewer than 5 H2 sections, push back: "This file is X lines / N sections — decomposition probably isn't worth it. Want to proceed anyway?"

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

**Read `~/.claude/skills/claude-md-improver/references/decomposition-heuristics.md` before classifying.** It's the canonical rubric — what stays at root, what extracts to `.claude/rules/`, what becomes a skill, plus glob heuristics for `paths:` frontmatter. Skipping this read produces classifications that drift from the audit skill's expectations, which means the next `claude-md-improver` audit re-flags everything you just moved.

For each section, pick a fate per that rubric:

| Fate | When |
|---|---|
| **Stay** | Project description, top-level command table, ≤30-line architecture, index of rule files, imports |
| **Extract → `.claude/rules/<topic>.md` (scoped)** | Path-scoped content that only matters under one dir/filetype |
| **Extract → `.claude/rules/<topic>.md` (unscoped)** | Cross-cutting but long enough to own a file (style guides, testing conventions) |
| **Extract → skill** | Multi-step procedure |
| **Extract → `CLAUDE.local.md`** | Personal/machine-specific content currently in committed CLAUDE.md |
| **Extract → `~/.claude/CLAUDE.md`** | Cross-project preferences misfiled here |
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
| How to add a feature | 220–260 | Extract → skill | ~/.claude/skills/add-feature/ |

### New root CLAUDE.md outline

(<approximate post-decomposition structure>)

### New files to create

- .claude/rules/api.md (~52 lines)
- .claude/rules/testing.md (~35 lines)
- CLAUDE.local.md (~15 lines)
- ~/.claude/skills/add-feature/SKILL.md (stub)

### .gitignore changes

- Add CLAUDE.local.md to .gitignore (if not already)
```

## Step 5: Confirm and apply

Wait for approval.

**Before writing anything, read `~/.claude/skills/claude-md-improver/references/templates.md`.** It has the canonical shapes for path-scoped rule files, unscoped rule files, `CLAUDE.local.md`, the `@AGENTS.md` import pattern, and the project-root post-decomposition layout. Improvising frontmatter or rule structure produces inconsistencies between this command's output and the audit skill's expectations — and YAML frontmatter is unforgiving about quoting, list syntax, and indentation, so working from a template avoids silent parse failures.

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

   <!-- Stubbed by /decompose-claude-md on YYYY-MM-DD from <source CLAUDE.md path>, section "<title>" (lines X-Y).
        Original content is preserved below verbatim — refactor into a proper skill workflow when ready. -->

   # <Original section title>

   <Original section body, copied verbatim.>
   ````

5. Rewrite the root CLAUDE.md with: imports at top → project description → command table → architecture overview → rules index table → top-level gotchas only
6. Run `wc -l` on the new root file and confirm it's under target

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

Report a one-line summary: "Decomposed CLAUDE.md from N→M lines, extracted X rule files (Y scoped, Z unscoped), W skill stubs, and moved K personal lines to CLAUDE.local.md."

## Pitfalls to avoid

- **Don't lose content silently.** Every removed line from the root must land somewhere or be explicitly dropped with the user's sign-off.
- **Don't aggressively scope.** If you're guessing at the `paths:` glob, leave the rule unscoped — better to load slightly more than needed than to silently miss context.
- **Don't fabricate skill bodies.** If a section was a procedure, extract it as a skill stub with the original section content; don't try to flesh it into a "proper" skill in this pass.
- **Don't decompose what's already small.** Push back when called on a tidy CLAUDE.md.
- **Preserve maintainer comments.** HTML comments at the top of CLAUDE.md (source pointers, last-synced dates) stay at root.

## Notes for the agent

- This command is destructive in the sense that it rewrites CLAUDE.md. Show the full plan before any writes. Get approval per the user's standard "confirm destructive actions" rule.
- If invoked from inside a `claude-md-improver` audit, you can carry forward the section inventory the audit produced — no need to re-discover.
