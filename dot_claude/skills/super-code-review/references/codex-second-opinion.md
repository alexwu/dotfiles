# Codex Second Opinion

The default-on second-opinion pass via `codex:codex-rescue`. Runs in parallel with our reviewers in Phase 2 at `--effort=high`.

## Why a second opinion

Our four reviewers share a model family. A genuinely independent second pass from a different model surfaces bugs we'd systematically miss, and corroborates findings we both flag (boosting their confidence at validation time).

`codex-rescue` forwards through the Codex companion runtime — so under the hood it's GPT-5-class reasoning rather than Claude. That difference is the value.

## Invocation

Codex-rescue is an **Agent subtype**, not a skill:

```
Agent(
  description: "Codex second-opinion code review",
  subagent_type: "codex:codex-rescue",
  prompt: <see below>,
  run_in_background: false
)
```

The agent definition (in `~/.claude/plugins/.../agents/codex-rescue.md`) is a thin forwarder — it doesn't do any analysis itself, it just shapes the prompt and shells out to the Codex companion. So our prompt must be **complete and self-contained** — the diff, the intent context, the task.

## Prompt template

```
Read-only code review.

CONTEXT
-------

Source mode: <pr|range|working>
Base SHA: <sha>
Head SHA: <sha or "working-tree">
PR number: <num if applicable>
Detected stack: <e.g., "iOS Swift / SwiftUI / SwiftData">

Changed files (<count>):
<list>

INTENT CONTEXT
--------------

<aggregated intent, or "(empty)">

DIFF
----

<inline diff if <50 KB, else paste content from $DIFF_FILE>

TASK
----

Review this diff for:
1. Bugs that will produce wrong results or fail to compile
2. Dropped error paths, missing returns, swapped arguments
3. Logic errors specific to the stack (e.g., Swift concurrency violations, Rust borrow issues, Python async pitfalls)
4. Subtle issues a senior reviewer would catch but a junior would miss

Constraints:
- Read-only. Do NOT propose edits. Do NOT modify files.
- Diff-focused. Do not flag issues outside the changed lines unless they're directly implicated.
- Quote evidence for every finding.
- Skip style, naming, formatting, and "could be cleaner" suggestions.
- If you cannot quote a specific line as evidence, do not flag the issue.

OUTPUT
------

Return findings as a structured list. Each finding:
- file: <path>
- line: <number>
- category: <bug|logic|type|error-path|concurrency|other>
- evidence: "<quoted line>"
- reasoning: "<one sentence why this is wrong>"
- confidence: <high|medium>

If no findings, return: "No issues found at high confidence."
```

## Forwarding flags

Per the `codex-rescue` agent's contract:

- Include `--read-only` (or equivalent — codex-rescue defaults to write-capable; we override)
- Include `--fresh` (don't resume prior Codex session; we want clean context)
- Do not set `--effort` or `--model` — let Codex pick defaults

The `codex-rescue` agent itself adds `--write` by default unless the user explicitly says read-only. For our use case, **always** signal read-only:

> "This is a review-only task. Do not propose or apply edits. Use --read-only."

Put that line at the top of the prompt; the codex-rescue agent forwards prompt text intact.

## Parsing the response

The codex-rescue agent returns the Codex companion's stdout exactly as-is. Expect either:

- A structured-list response matching our requested format (best case)
- Free-form markdown with findings interleaved with prose (parse with regex / heuristics)
- An error / empty response if Codex was unavailable

Parser strategy:

1. Try to match the structured format first
2. If not structured, extract `file:line` references and any quoted code blocks
3. If neither, treat the response as a single "Codex narrative" finding with severity=suggestion and pass it through to output as-is (the user can read it themselves)

## When Codex is unavailable

If the Agent spawn returns nothing, or returns an error message indicating Codex couldn't be invoked:

- Do NOT retry — Codex CLI errors are rarely transient and retrying wastes spend
- Proceed to Phase 3 without the second-opinion findings
- Note in the final output: `(Codex second opinion was unavailable for this run.)`

## Merging Codex findings with our reviewers'

Codex findings go through Phase 3 validation just like our reviewers' findings. The validator doesn't know which agent produced the finding — that's intentional, it should judge on evidence.

When deduping in Phase 4:
- If a Codex finding overlaps with one of ours (same file, overlapping line range, same category), keep the version with higher reported confidence and tag `discovered_by: [bug-reviewer, codex]`
- If a Codex finding is unique, keep it
- If only Codex flagged a particular issue and validation confirms it, that's high signal — Codex catching something we missed is the whole point

## Cost note

Codex runs through the user's Codex subscription. One call per super-code-review invocation at `--effort=high`. At `--effort=low` and `--effort=medium`, Codex is skipped.

If the user wants to suppress Codex on a specific high-effort run (e.g., for a sensitive repo where intent context shouldn't leave the machine), add `--no-codex` as a future flag. For now, the only way to skip Codex is to drop to `--effort=medium`.
