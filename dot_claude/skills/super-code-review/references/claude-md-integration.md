# CLAUDE.md Integration

How the orchestrator and the `claudemd-compliance-reviewer` integrate with the existing `claude-md-improver` and `decompose-claude-md` skills.

## The three relevant skills

| Skill | What it does | Used by |
|---|---|---|
| `claudemd-compliance-reviewer` (agent) | Audits a diff against scoped CLAUDE.md rules | super-code-review Phase 2 |
| `claude-md-improver` (skill) | Audits the CLAUDE.md files themselves — finds outdated rules, missing rules, growing-too-large issues | Suggested by super-code-review when its compliance reviewer detects systemic problems |
| `decompose-claude-md` (command/skill) | Refactors an oversized CLAUDE.md by extracting sections into `.claude/rules/*.md` | Suggested when the root CLAUDE.md is bloated |

These are layered: the **reviewer** finds rule *violations* in the diff; the **improver** finds rule *quality* issues in the CLAUDE.md itself; the **decomposer** restructures bloated CLAUDE.md files.

## When to suggest `claude-md-improver`

After Phase 4 (merge), if any of these conditions hold, append a suggestion to the output:

- The compliance reviewer flagged a violation against a rule that looks **outdated** (rule references an API or pattern that doesn't exist in the current code)
- The compliance reviewer flagged ≥3 violations of the same rule across the diff (signal that the rule may not match how the code actually wants to be written, or the rule is poorly worded)
- The compliance reviewer reported gaps ("I expected a rule about X but couldn't find one") for a recurring pattern in the diff

Suggestion text:
```
Consider running /claude-md-improver to audit CLAUDE.md quality.
This review surfaced rule-quality concerns: <list>.
```

Do NOT auto-run it. The user invokes it when they're ready.

## When to suggest `decompose-claude-md`

If the compliance reviewer's process step "Discover applicable instruction files" reports that any single CLAUDE.md or AGENTS.md it had to read was **over ~500 lines**, append a suggestion:

```
The root CLAUDE.md is N lines, which is enough to start losing context.
Consider running /decompose-claude-md to split it into .claude/rules/<topic>.md files.
```

Heuristic for "over 500 lines": `wc -l` > 500 for any `CLAUDE.md` or `AGENTS.md` traversed (measure the imported file, not a stub). Don't fire this for `.claude/rules/*.md` files — those are already decomposed by definition. For an oversized `AGENTS.md`, `decompose-claude-md` splits it spatially into nested per-directory `AGENTS.md` files instead of extracting to `.claude/rules/`.

## Passing context to the compliance reviewer

Repos keep their rules in `CLAUDE.md`, `AGENTS.md`, or both. A common layout, used across the `lulu-*` repos, is an `AGENTS.md` holding every rule and a `CLAUDE.md` stub whose only content is `@AGENTS.md`. Discovery has to follow that import, or the reviewer checks an empty stub and reports a clean pass.

The reviewer's spawn prompt should include:

```
INSTRUCTION FILE DISCOVERY
==========================

For each changed file, walk from the file's directory up to the repo root.
Collect every CLAUDE.md, AGENTS.md, and AGENTS.override.md encountered.
Follow `@path` imports. Collect `.claude/rules/*.md`, keeping only those
whose `paths:` frontmatter globs match a changed file (no `paths:` means
repo-wide). Read a file once when another symlinks to or imports it.

Pre-discovered (run before spawn for efficiency):
- /repo/CLAUDE.md and/or /repo/AGENTS.md
- /repo/<subdir>/{CLAUDE,AGENTS}.md (for each changed path's lineage)
- /repo/.claude/rules/*.md (the ones whose paths match)
- ~/.claude/CLAUDE.md, ~/.claude/rules/*.md, ~/.codex/AGENTS.md (user-level —
  apply to every diff; scope decided by entry point, see below)

The reviewer should Read these in full at the start of its run.
```

Include both user-level files whenever they exist, regardless of which agent runs the review. Some of Alex's rules live there (TODO attribution, for one), and they apply to code whichever agent wrote it.

## User-level rules stay local

`~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, and `~/.codex/AGENTS.md` are Alex's personal rules. The repo's other contributors never agreed to them, so a finding sourced **only** from a user-level file (`rule_scope: user`) is a note to Alex, never a review finding.

Scope is decided by **entry point**. These files are symlinks into a prompts repo on Alex's machine, so the resolved path looks like neither a user file nor a repo file. Anything reached from a user-level entry point, through any symlink or `@` import, is user scope.

- It goes in the local summary's **Personal-rule notes** section (see `output-formats.md`), not in the severity buckets.
- It is **never** posted as a PR comment or included in any review posted to the PR, and it never affects whether a review approves or blocks.
- It skips Phase 3 validation's severity assignment; the validator only confirms it's real.
- Phase 4 partitions it into `user_rule_notes` before sorting (see `agent-prompts.md` → "Result merge format").

When the same rule also appears in a repo-level file, the repo file is the source and the finding is a normal one. The shortcut reviewer's `TODO(alexwu)` attribution check comes from the user-level file, so it follows this rule too.

## How the reviewer integrates `claude-md-improver`'s philosophy

The `claude-md-improver` skill includes guidance on what makes a *good* CLAUDE.md rule. The reviewer can use this as a sanity check on whether a "violation" is actually meaningful:

- A rule worth enforcing is **specific** (mentions a concrete pattern), **testable** (a reviewer can quote evidence), and **scoped** (clear when it applies)
- A rule like "write good code" is not enforceable — don't flag against it
- A rule like "TODOs must be attributed as `TODO(name):`" is enforceable — flag clearly when the diff adds one that isn't
- A rule about how the agent works in a session ("use the ctx7 CLI for library docs") is enforceable in a session, but no diff can violate it — don't flag it

If the reviewer encounters a non-enforceable rule, it skips it (no flag) AND reports it as a gap ("CLAUDE.md contains rule X but it's too vague to enforce").

## Cross-link to `claude-md-improver`'s own audit

If the user already ran `claude-md-improver` recently (check for a `.claude/claude-md-improver-report.md` or similar artifact), and the report mentioned specific rules that need updating, the reviewer should know about it and de-prioritize flagging those rules (they're already known-broken).

Path to check: `.claude/`, `~/.claude/projects/<repo-id>/memory/`, repo root for a `CLAUDE_MD_AUDIT.md` or equivalent. If found, surface a note in the output that an existing improver report should be consulted alongside this review.

## What this skill does NOT do

- It does not edit CLAUDE.md or AGENTS.md files
- It does not run `claude-md-improver` or `decompose-claude-md`
- It does not refactor rule wording

Suggestions only. The user pilots.
