# Templates

<!--
Source: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04
-->

Lean templates for each surface. Pick what's relevant; don't include sections you can't fill with project-specific content.

## Project root CLAUDE.md (target ≤200 lines)

```markdown
# <Project Name>

<One-line description.>

Reference docs are split across `.claude/rules/`:

| File | Covers |
|------|--------|
| `setup.md`  | Install, env vars, dev server |
| `testing.md`| Test commands, fixtures, conventions |
| `deploy.md` | Release process |

## Commands

| Command | Description |
|---------|-------------|
| `pnpm dev` | Dev server on :3000 |
| `pnpm test` | Watch mode |
| `pnpm build` | Production build |

## Architecture

```
src/
  api/      # HTTP handlers
  core/     # Domain logic
  ui/       # React components
```

## Gotchas

- <project-specific gotcha>
- <ordering dependency>
```

## `.claude/CLAUDE.md` (alternative project location)

Same shape as project root CLAUDE.md. Use when the user prefers grouping all Claude config under `.claude/`. Both `./CLAUDE.md` and `./.claude/CLAUDE.md` are valid; don't load both — the doc treats them as alternatives.

## `.claude/rules/<topic>.md` — path-scoped rule

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "tests/api/**"
---

# API conventions

- All endpoints validate input with Zod schemas in `src/api/schemas/`
- Error responses use the envelope in `src/api/errors.ts`
- Auth middleware ordering: `withAuth` → `withRateLimit` → handler
```

Glob patterns:

| Pattern | Matches |
|---|---|
| `**/*.ts` | All TypeScript files in any directory |
| `src/**/*` | All files under `src/` |
| `*.md` | Markdown files in project root only |
| `src/**/*.{ts,tsx}` | Brace expansion across extensions |

A rule without `paths:` loads on every session at the same priority as `.claude/CLAUDE.md`. Use that for genuinely project-wide content; use `paths:` for file-specific content.

## `.claude/rules/<topic>.md` — unscoped rule

```markdown
# Code style

- 2-space indentation across the project
- Prefer functional over class-based React components
```

No frontmatter. Loads always.

## User-level — `~/.claude/CLAUDE.md`

```markdown
# Personal preferences

- Use ripgrep over grep, fd over find, eza over ls
- Prefer Conventional Commit messages
- Quote file paths with spaces
```

## User-level path-scoped — `~/.claude/rules/<topic>.md`

```markdown
---
paths:
  - "**/*.swift"
---

# Swift preferences

- Use `if let foo` instead of `guard let foo = foo`
- Prefer `async let` over `withTaskGroup` for ≤3 parallel calls
```

## `CLAUDE.local.md` — gitignored project preferences

```markdown
# Local notes (do not commit)

- Sandbox URL: https://my-sandbox.local:8443
- Test user: dev+local@example.com / hunter2
- Feature flag overrides for local dev
```

Add to `.gitignore`. For multi-worktree repos, use a home-dir import instead:

```markdown
# CLAUDE.local.md
@~/.claude/this-project-local.md
```

## CLAUDE.md → AGENTS.md import

Existing `AGENTS.md` should be imported, not duplicated:

```markdown
# CLAUDE.md
@AGENTS.md

## Claude-specific

<Claude Code-only instructions go here, after the import.>
```

## Monorepo: `claudeMdExcludes`

If other teams' CLAUDE.md files in the same monorepo aren't relevant, exclude them in `.claude/settings.local.json`:

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/abs/path/to/other-team/.claude/rules/**"
  ]
}
```

Glob-matched against absolute paths. Configurable at user, project, local, or managed-policy layers (arrays merge).

## Maintainer notes via HTML comments

Block-level HTML comments are stripped from CLAUDE.md before injection — useful for source pointers and provenance:

```markdown
# CLAUDE.md

<!--
Last refresh: 2026-05-04
Source authoritative doc: https://code.claude.com/docs/en/memory.md
Maintainer: alex
-->

<!-- The text above never enters Claude's context window. -->

## Commands
...
```

Comments inside fenced code blocks are preserved. When you open CLAUDE.md with the Read tool, comments are visible.

## Update principles

- Be specific: real paths, real commands, real env var names
- Be current: cross-check against the codebase before adding
- Be brief: one line per concept; tables beat paragraphs
- Be useful: would this help a fresh Claude session?
