# Effort Tiers

What runs at each `--effort` level. Default is `high`. The skill is opinionated: `high` is the right answer for almost all real PR reviews; the other tiers exist for cost/time control.

## `low` — Quick sanity

**Use when:** uncommitted scratch work, you want a 30-second gut check, the diff is small (<200 lines) and you trust yourself on style/tests.

| Phase | Action |
|---|---|
| 1 (Gather) | Diff + changed-file list only. **Skip** intent gathering, **skip** domain profile detection |
| 2 (Fan-out) | `bug-reviewer` only |
| 3 (Validation) | **Skip** — bug-reviewer outputs ship as-is |
| 4 (Merge) | Pass-through |
| 5 (Output) | Terminal summary |
| 6 (CodeRabbit) | Honored if `--coderabbit` flag is set |

No Codex second opinion. No domain auditors. Single-agent throughput.

## `medium` — Pre-commit

**Use when:** finalizing a local branch before push, you want CLAUDE.md compliance + shortcut detection without the full deep dive.

| Phase | Action |
|---|---|
| 1 (Gather) | Diff + intent context (PR body / commits / plan files) + minimal domain detection (language only) |
| 2 (Fan-out) | `bug-reviewer`, `claudemd-compliance-reviewer`, `shortcut-intent-reviewer` |
| 3 (Validation) | Yes — but **batched aggressively** (all findings per file → one validator) |
| 4 (Merge) | Standard |
| 5 (Output) | Terminal summary |
| 6 (CodeRabbit) | Honored if flag set |

**Skipped:** test-thoroughness-reviewer, domain auditors, Codex second opinion.

## `high` — PR review (default)

**Use when:** reviewing a real PR, finalizing a feature branch, anything that's going to be merged.

| Phase | Action |
|---|---|
| 1 (Gather) | Full — diff + intent (all 4 sources unless `--intent` narrows it) + domain profile detection |
| 2 (Fan-out) | All four generic reviewers + all matching domain auditors + Codex second opinion (all parallel) |
| 3 (Validation) | Full per-finding validation, batched by file when 2+ findings collide |
| 4 (Merge) | Dedupe across our reviewers + Codex, severity-tag |
| 5 (Output) | Terminal summary by default; `--comment` posts inline; `--json` for CI |
| 6 (CodeRabbit) | Honored if flag set |

This is the canonical pipeline. Everything else is a subset.

## `ultra` — Defers to harness

The harness owns `/code-review ultra` — a billed cloud multi-agent pass. This skill cannot launch it (per the system rule about user-triggered/billed commands).

**Behavior:** when `--effort=ultra` is passed, output the following message and stop:

```
Effort=ultra delegates to the built-in harness command, which runs a billed
multi-agent cloud review. Run it directly:

  /code-review ultra

If you want our deepest local pass, run --effort=high instead.
```

Do not attempt to invoke `/code-review` via Bash or any other route.

## Effort selection heuristics (when the user doesn't specify)

These are advisory — the user can always override:

- Diff < 50 lines, working-tree mode → suggest `low`
- Diff 50–500 lines, range or working-tree → suggest `medium`
- Diff > 500 lines, or PR mode → `high` is the default and right answer
- User says "thorough", "deep", "ship-ready" → `high`
- User says "quick", "sanity check", "fast" → `low` or `medium`

The skill should respect explicit `--effort` flags. Only suggest a different tier when no flag is set and the diff size strongly signals a mismatch.
