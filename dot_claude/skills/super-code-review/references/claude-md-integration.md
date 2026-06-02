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

If the compliance reviewer's process step "discover applicable CLAUDE.md files" reports that any single CLAUDE.md it had to read was **over ~500 lines**, append a suggestion:

```
The root CLAUDE.md is N lines, which is enough to start losing context.
Consider running /decompose-claude-md to split it into .claude/rules/<topic>.md files.
```

Heuristic for "over 500 lines": `wc -l < CLAUDE.md` > 500 in any of the CLAUDE.md files traversed. Don't fire this for `.claude/rules/*.md` files — those are already decomposed by definition.

## Passing context to the compliance reviewer

The reviewer's spawn prompt should include:

```
APPLICABLE CLAUDE.md DISCOVERY
==============================

For each changed file, walk from the file's directory up to the repo root.
Collect every CLAUDE.md encountered. Also collect any `.claude/rules/*.md`
files referenced from a scoped CLAUDE.md.

Pre-discovered (run before spawn for efficiency):
- /repo/CLAUDE.md (always)
- /repo/<subdir>/CLAUDE.md (for each changed path's lineage)
- /repo/.claude/rules/*.md (if any are referenced)
- ~/.claude/CLAUDE.md (the user's global rules — always applies to every diff)

The reviewer should Read these in full at the start of its run.
```

The `~/.claude/CLAUDE.md` (global / user-level instructions) **always applies** — include it in the pre-discovery list every time. Many of Alex's rules live there (TODO attribution, tool preferences, etc.).

## How the reviewer integrates `claude-md-improver`'s philosophy

The `claude-md-improver` skill includes guidance on what makes a *good* CLAUDE.md rule. The reviewer can use this as a sanity check on whether a "violation" is actually meaningful:

- A rule worth enforcing is **specific** (mentions a concrete pattern), **testable** (a reviewer can quote evidence), and **scoped** (clear when it applies)
- A rule like "write good code" is not enforceable — don't flag against it
- A rule like "use ctx7 CLI for library docs" is enforceable — flag clearly when the diff doesn't

If the reviewer encounters a non-enforceable rule, it skips it (no flag) AND reports it as a gap ("CLAUDE.md contains rule X but it's too vague to enforce").

## Cross-link to `claude-md-improver`'s own audit

If the user already ran `claude-md-improver` recently (check for a `.claude/claude-md-improver-report.md` or similar artifact), and the report mentioned specific rules that need updating, the reviewer should know about it and de-prioritize flagging those rules (they're already known-broken).

Path to check: `.claude/`, `~/.claude/projects/<repo-id>/memory/`, repo root for a `CLAUDE_MD_AUDIT.md` or equivalent. If found, surface a note in the output that an existing improver report should be consulted alongside this review.

## What this skill does NOT do

- It does not edit CLAUDE.md files
- It does not run `claude-md-improver` or `decompose-claude-md`
- It does not refactor rule wording

Suggestions only. The user pilots.
