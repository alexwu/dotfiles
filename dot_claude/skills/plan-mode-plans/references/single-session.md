# Single-Session (variant reference)

This is the default variant. Loaded when the task fits in one session and lives in a single plan `.md` file.

## What this variant is

- Plan is a **single Markdown file** (not a directory).
- Steps are a **flat numbered list** with file paths and code snippets per the universal rules in SKILL.md.
- The lead does all exploration directly (no agent team).
- Phase 4.5 uses `references/audit-prompt-single.md`.

## What overrides apply

**None.** The universal patterns in SKILL.md — Required Sections template, Code Snippets, Specificity Requirements, Self-Containment Test, universal Common Mistakes — apply directly with no modifications.

If the user asks for TDD on a single-session plan, also load `tdd-cycles.md`. The combination overrides only the Steps section format (flat list → red/green/refactor cycles).

If the task grows mid-planning into something that touches 3+ independent areas, switch to the agent-teams variant (`references/agent-teams.md`). Don't try to stretch single-session past 1-2 focused areas — context exhaustion is real and the multi-file structure of agent-teams exists to prevent it.

## Self-Containment Test (single-file specific)

The base self-containment test from SKILL.md is sufficient. The only single-session-specific thing to verify:

- The plan file passes `check-plan <plan-path>` (Phase 4.5 invokes this; if it fails, fix the plan and re-audit).
