# Routing: which surface does this content belong on?

<!--
Source: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04
-->

The single most useful change vs the legacy plugin: every piece of content has a *correct* surface, and most "CLAUDE.md is messy" complaints are really "content is on the wrong surface." Use this tree.

## Decision tree

```
Is this a multi-step procedure or task workflow?
├─ Yes → SKILL (in ~/.claude/skills/<name>/ or .claude/skills/<name>/)
│        Skills load on demand only; CLAUDE.md content loads every session.
│
└─ No → Continue
   │
   Is this content useful only when working with specific files/dirs?
   ├─ Yes → .claude/rules/<topic>.md  with paths: frontmatter
   │        e.g. API conventions only matter when editing src/api/**
   │
   └─ No → Continue
      │
      Is this Claude-discovered (a correction the user gave, or an inference
      from session behavior)?
      ├─ Yes → AUTO MEMORY (~/.claude/projects/<proj>/memory/)
      │        Don't write this manually; ask the user to confirm the
      │        learning instead, and let auto memory capture it. Or, if they
      │        want it persisted as an explicit instruction (not a learning),
      │        add to CLAUDE.md.
      │
      └─ No → Continue
         │
         Is this private to the user (sandbox URLs, personal preferences,
         test creds)?
         ├─ Yes → CLAUDE.local.md (project) or ~/.claude/CLAUDE.md (global)
         │        CLAUDE.local.md must be gitignored.
         │
         └─ No → Continue
            │
            Is this the same instructions other coding agents (Codex, Cursor)
            would also need?
            ├─ Yes → AGENTS.md, imported via @AGENTS.md from CLAUDE.md
            │
            └─ No → CLAUDE.md (project root or .claude/CLAUDE.md)
```

## Surface descriptions

### Skill — `~/.claude/skills/<name>/SKILL.md` or project `.claude/skills/<name>/SKILL.md`

Use for: multi-step workflows, repeatable procedures, task-specific tooling. Skills load on demand when triggered by description match — they don't burn context every session.

Example moves into a skill:
- "How to set up a new feature branch" with 6 steps
- "Debugging the Foo subsystem" with a procedure
- Anything starting with "First, ... Then, ... Finally, ..."

### Path-scoped rule — `.claude/rules/<topic>.md`

Use for: instructions that only matter when Claude works with files matching specific paths. Frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "tests/api/**"
---
# API conventions
- All endpoints must validate input with Zod
- Error responses use the standard envelope in src/api/errors.ts
```

Path-scoped rules trigger when Claude reads matching files, not on every prompt. They're cheaper than CLAUDE.md content and scoped where they're useful.

Without `paths:` frontmatter, a rule loads at launch with the same priority as `.claude/CLAUDE.md` — fine for project-wide content, but flag the missing frontmatter as **unscoped** if the content is clearly path-specific.

### Auto memory — `~/.claude/projects/<derived>/memory/`

Claude-owned. Don't manually write here. The first 200 lines or 25KB of `MEMORY.md` load every session; topic files load on demand.

Tells you a learning belongs here:
- Originated from a user correction or preference Claude noticed
- Specific to one machine/project
- Would feel weird to commit (machine state, debugging insight)

Tells you a learning belongs in CLAUDE.md instead:
- Team-relevant (other contributors need it)
- Authored by the user as an explicit rule, not inferred
- The user explicitly says "add this to CLAUDE.md"

If a learning is duplicated between CLAUDE.md and auto memory: prefer the user-authored CLAUDE.md version and ask Claude to drop the auto-memory copy on its next pass (or just delete the auto-memory file directly — they're plain markdown).

### Project CLAUDE.md — `./CLAUDE.md` or `./.claude/CLAUDE.md`

Both paths work. Prefer `./CLAUDE.md` for new projects (more discoverable); use `./.claude/CLAUDE.md` if the user wants Claude config grouped under `.claude/`. Walk-up loading concatenates all CLAUDE.md files from filesystem root to working directory; instructions closer to the working directory are read last.

Target ≤200 lines per file. If approaching the limit, decompose into `.claude/rules/` first, imports second.

### `CLAUDE.local.md`

Project-scoped, gitignored. Personal preferences for the project. Loaded right after CLAUDE.md at the same level. Add to `.gitignore` (or use `/init` and pick the personal option, which does it for you).

For multi-worktree repos, gitignored files only exist in the worktree where created — instead, import a home-directory file:

```markdown
# Personal preferences
- @~/.claude/this-project.md
```

### User-level — `~/.claude/CLAUDE.md` and `~/.claude/rules/*.md`

Loaded for every project on the machine. Use for cross-project preferences. User rules without `paths:` load before project rules.

### Managed policy CLAUDE.md

Org-wide deployment via MDM/Group Policy. Cannot be excluded by individual settings. Reserved for compliance, security, and behavioral guidance company-wide. Don't recommend creating one casually.

### `AGENTS.md`

Convention used by other coding agents. Claude Code reads `CLAUDE.md`, not `AGENTS.md`. To make both work without duplication, import:

```markdown
# CLAUDE.md
@AGENTS.md

## Claude-specific
- Anything Claude Code-specific goes here, after the import.
```

## Common misroutings (flag during audit)

| Symptom | Wrong surface | Right surface |
|---|---|---|
| Multi-step procedure (>3 steps) in CLAUDE.md | CLAUDE.md | Skill |
| Section that only mentions files under one directory | CLAUDE.md | `.claude/rules/<dir>.md` with `paths:` |
| Personal sandbox URL or test creds in CLAUDE.md | CLAUDE.md (committed) | `CLAUDE.local.md` (gitignored) |
| User wrote "always do X" in chat, Claude added it to MEMORY.md | Auto memory | CLAUDE.md (user-authored intent) |
| Same instruction in CLAUDE.md and `.claude/rules/foo.md` | Both | One only — usually the rules file (more scoped) |
| Project has AGENTS.md but CLAUDE.md doesn't import it | (drift) | Add `@AGENTS.md` |
| `.claude/rules/security.md` with no `paths:` but content is auth-only | Unscoped rule | Add `paths: ["src/auth/**"]` |
| `.claude.local.md` (legacy filename) | Misnamed | Rename to `CLAUDE.local.md` |
