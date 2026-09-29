# Codex Second Opinion

The default-on second-opinion pass via `codex:codex-rescue`. Runs in parallel with our reviewers in Phase 2 at `--effort=high`.

## Why a second opinion

Our five reviewers share a model family. A genuinely independent second pass from a different model surfaces bugs we'd systematically miss, and corroborates findings we both flag (boosting their confidence at validation time).

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

<PASS CONTEXT block, exactly as in agent-prompts.md → "Reviewer spawn template">

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
- in_delta: <true|false>; regression: <true|false>; matches: <url, when set>

If no findings, return: "No issues found at high confidence."
```

## Forwarding flags

Open the prompt with this exact line. `codex-rescue` reads `--model` and `--effort` as runtime controls and strips them from the task text:

```text
--effort high --fresh --read-only
```

- **No `--model`**: Codex runs its configured default (`codex-config.toml`). Add `--model <id>` only when the user names a model for this review, and pass their id verbatim. Never pick one yourself: stale lists elsewhere (the disabled `skill-codex` plugin's menu, for one) have steered subagents to `gpt-5.3-codex`, which this account rejects, and then to older fallbacks.
- **`--effort high`**: the config default is `medium`, too low for a review.
- **`--fresh`**: don't resume a prior Codex session.
- **`--read-only`**: `codex-rescue` defaults to write-capable, so always override it.

Also state it in words right after the flags line, since the agent forwards prompt text intact:

> "This is a review-only task. Do not propose or apply edits."

**If Codex rejects the model** (an unsupported-model or 400 error), the second opinion is unavailable for this run. Report it that way. Don't retry with a different model.

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

## `--skip-codex`

Skips the Codex second opinion on a `high` run and changes nothing else: the other reviewers, validation, and output run as usual. Don't spawn `codex:codex-rescue` at all. In the output, write `(Codex second opinion skipped: --skip-codex.)` in place of the unavailable note, and set `second_opinion.status` to `"skipped"` in `--json`. At `low` and `medium` the flag has no effect, since Codex doesn't run there.
