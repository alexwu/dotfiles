# Update guidelines — what to add, what to skip

<!--
Source: https://code.claude.com/docs/en/memory.md
Last synced: 2026-05-04
-->

## Core principle

Memory files are loaded into context every session (CLAUDE.md, rules without `paths:`) or on demand (path-scoped rules, skills). Every line costs tokens and reduces adherence to other lines. Add only what helps a future session.

## What to add

### 1. New features or systems built this session

This is what the legacy plugin missed. When the session built a real feature, future Claude needs to know it exists and how to extend it.

```markdown
## Features

- `src/notifier/` — apprise + grrr-based Stop/Notification hook backends; pluggable via the `notifiers` array
- `src/sec_guard/` — PreToolUse Edit/Write guard with 9 rules, session-scoped dedup
```

Why: a new module is invisible from CLAUDE.md unless someone documents it. Without this entry, the next session reinvents the integration boundary.

### 2. Commands and workflows discovered

```markdown
## Build

- `nim c -o:~/.local/bin/foo scripts/foo.nim` — direct rebuild without full chezmoi apply
- `chezmoi apply` re-runs every changed template, so prefer the direct command for one-off rebuilds
```

Why: saves rediscovery.

### 3. Gotchas and non-obvious patterns

```markdown
## Gotchas

- Tests must run with `--runInBand`; shared DB state breaks parallel runs
- `yarn.lock` is authoritative; delete `node_modules` if deps mismatch
```

Why: prevents repeating the debugging session that uncovered them.

### 4. Cross-module relationships

```markdown
## Module ordering

The `auth` module needs `crypto` initialized first. Import order in `src/bootstrap.ts` matters.
```

Why: architecture knowledge that's not visible from any single file.

### 5. Configuration quirks

```markdown
## Config

- `NEXT_PUBLIC_*` vars must be set at build time, not runtime
- Redis connection requires `?family=0` for IPv6
```

### 6. Conventions established this session

If a session established a new pattern (e.g. "from now on, hooks live in `scripts/claude/` and are Nim with cligen `dispatchMulti`"), capture the convention so the next time someone adds a hook they don't reinvent the structure.

## What NOT to add

### Obvious from the code

```markdown
The `UserService` class handles user operations.
```

Class name says it. Skip.

### Generic best practices

```markdown
Always write tests for new features.
Use meaningful variable names.
```

Universal advice. Doesn't earn its tokens.

### One-off fixes

```markdown
Fixed a bug in commit abc123 where login broke.
```

Won't recur. Leave it in the commit log.

### Verbose explanations

Bad:

```markdown
The auth system uses JWT tokens. JWT (JSON Web Tokens) are an open
standard (RFC 7519) defining a compact, self-contained way to securely
transmit information between parties as JSON...
```

Good:

```markdown
Auth: JWT HS256, `Authorization: Bearer <token>` header.
```

### Things auto memory will catch

If it's a learning Claude noticed (a correction, a preference inferred from session behavior), let auto memory handle it. Manually adding to CLAUDE.md duplicates effort and risks the same line ending up in both surfaces.

Tells:
- "Whenever I tell you X, you keep doing Y" → auto memory's territory
- "Always use rg over grep" → goes in CLAUDE.md (user-authored explicit rule)

When in doubt: ask the user "should I add this to CLAUDE.md, or let auto memory pick it up?"

## Capture format per addition

Each addition gets:

```
### Addition: <surface path>

**Why:** <one-line reason — what future sessions gain>

**Surface choice:** <CLAUDE.md | .claude/rules/<file> | CLAUDE.local.md | skill | auto memory>

```diff
+ <the addition>
```
```

For new feature captures specifically:

```
### Addition: ./CLAUDE.md (new section)

**Why:** This session built `scripts/claude/persona_anchor.nim` (SessionStart + UserPromptSubmit hook). Without documenting it, the next session would have no idea this hook exists or how to extend it.

**Surface choice:** CLAUDE.md (project-wide; affects all hook work in this repo)

```diff
+ ## Hooks
+
+ - `persona_anchor.nim` — SessionStart + UserPromptSubmit; re-injects compressed CLAUDE.md recap.
+   Knobs: `ENABLE_PERSONA_ANCHOR=0`, `PERSONA_ANCHOR_FREQUENCY=N` (default 10).
+   State at `~/.claude/persona_anchor/<sid>.json`.
```
```

## Validation checklist

Before applying:

- [ ] Project-specific (not generic)
- [ ] Commands tested and work
- [ ] Paths exist
- [ ] Smaller surface preferred over CLAUDE.md when content is path-scoped
- [ ] Most concise expression of the info
- [ ] Wouldn't have been auto-captured anyway
