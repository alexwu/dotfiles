# Decomposition heuristics

<!--
Source: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04
Used by /decompose-claude-md and by the auditor to flag oversized files.
-->

When and how to break a CLAUDE.md into `.claude/rules/`.

## When to decompose

Trigger any of these:

| Signal | Threshold | Action |
|---|---|---|
| Line count | >200 lines | Strong recommend decompose |
| Section count | ≥5 H2 sections | Likely candidate; check section sizes |
| Single section length | >40 lines | That section is a candidate to extract |
| Path-scoped content | Section's content references only files under one dir | Extract with `paths:` frontmatter |
| Multi-step procedure | Numbered steps, "first/then/finally" | Extract to a skill instead of a rule |
| Topic shift | Section is about a separate concern from the rest | Candidate for extraction |

## What stays at the root vs what extracts

### Stays in CLAUDE.md root

- One-paragraph project description
- Top-level command table (build, test, dev, lint)
- Architecture overview (one tree, ≤30 lines)
- Index of `.claude/rules/` contents (table mapping file to topic)
- Anything that's genuinely project-wide and short
- `@AGENTS.md` import line if applicable

### Extracts to `.claude/rules/<topic>.md`

- Sections that only describe behavior under one directory or filetype
- Code-style conventions detailed enough to be their own thing
- Testing conventions (often path-scopable to `tests/**` or `**/*.test.ts`)
- Domain-specific deep dives (auth flow, billing rules, persistence layer)
- Long gotcha lists for one subsystem

### Extracts to a skill

- Multi-step workflows ("how to add a new feature flag")
- Repeatable procedures with branching ("if X, do Y; else Z")
- Anything that says "the process is:" followed by a numbered list

### Extracts to `CLAUDE.local.md`

- Personal sandbox URLs, test creds, machine-specific paths
- Personal-preference overrides for project conventions

### Extracts to `~/.claude/CLAUDE.md`

- Cross-project preferences accidentally placed in project memory

## Naming

Rule files:
- One topic per file
- Lowercase kebab-case: `api.md`, `testing.md`, `database-migrations.md`
- Group related rules in subdirectories: `frontend/components.md`, `frontend/styling.md`
- Resist over-splitting — under 5 lines isn't worth a separate file

## `paths:` frontmatter heuristics

| Section content | Suggested glob |
|---|---|
| Mentions only `src/api/**` | `["src/api/**/*.{ts,tsx}"]` |
| Mentions only test files | `["**/*.test.ts", "tests/**"]` |
| Mentions only Swift | `["**/*.swift"]` |
| Mentions only `package.json` etc | `["package.json", "pnpm-lock.yaml"]` |
| Cross-cutting (multiple dirs) | Either no frontmatter (loads always) or list all directories |

If you can't decide between unscoped and scoped, lean unscoped. The cost of a small unscoped file is bounded; the cost of a scoped file that doesn't trigger when it should is silent missing context.

## After decomposition

The new root CLAUDE.md should:

- Stay under ~80 lines
- Include an index pointing at `.claude/rules/` files
- Keep imports near the top (`@AGENTS.md`, `@~/.claude/personal.md`)
- Remove every line that was extracted (no duplication)

Verify line count: `wc -l CLAUDE.md` afterward.

## Common pitfalls

- **Don't extract `paths:`-scoped rules into a directory the rule itself targets** — keeping rule files in `.claude/rules/` is the convention; the `paths:` field handles scoping.
- **Don't extract too aggressively.** A 120-line CLAUDE.md with three coherent sections doesn't need to be split.
- **Don't lose context in extraction.** If a section references "see above" or "as mentioned earlier," fix the reference when extracting.
- **Don't create a rule file with no `paths:` and one-line content.** That's worse than leaving it in CLAUDE.md.
