# Agent Spawn Prompt Templates

How the orchestrating skill assembles spawn prompts for the reviewers and validators. Each prompt must be **self-contained** — the spawned subagent doesn't see the orchestrator's conversation history.

## Reviewer spawn template (used for all four generic reviewers + Codex)

```
You are being spawned as part of a super-code-review pipeline. Your role: <agent-name>.

CONTEXT
-------

Source mode: <pr | range | working>
Base SHA: <sha>
Head SHA: <sha or "working-tree">
PR number: <num> (if applicable)

Changed files (<count>):
<bulleted list of paths>

Domain profile detected: <e.g., "iOS Swift + SwiftUI + SwiftData" or "generic">

INTENT CONTEXT
--------------

<paste of the aggregated intent context, or "(empty)">

DIFF
----

<either inline diff if <50 KB, or "See file: /tmp/super-code-review-diff-XXXXX.patch">

TASK
----

Follow your agent definition's process. Return findings in the format specified in your agent definition. Do not return prose outside the structured findings.
```

Pass this as the `prompt` argument to `Agent({subagent_type: "<role>", prompt: "<above>"})`.

## Domain auditor spawn template (axiom:*-auditor, etc.)

Axiom auditors are general-purpose agents that read the whole repo on their own. They don't have a "review-this-diff" contract by default. Adapt the prompt to focus them:

```
You are being invoked as part of a super-code-review pipeline. Your normal job is to scan the entire repo, but for this run we only want findings in the diff.

Changed files in scope (only flag findings in these files):
<list>

The diff is at <path or inline>.

Run your normal audit, but suppress any finding whose file path is not in the in-scope list. Report findings in the format your skill normally produces.
```

If a particular axiom auditor can't be constrained this way, run it normally and post-filter its output against the changed-files list at the merge phase.

## Codex second-opinion spawn template

See `codex-second-opinion.md` for the full Codex invocation. The prompt content shape:

```
Read-only review of the following diff. Identify bugs and quality issues you can quote evidence for. Do not propose edits; this is review-only.

CONTEXT
-------

<source mode, SHAs, file list>

INTENT CONTEXT
--------------

<intent or "(empty)">

DIFF
----

<diff>

Return your findings as a structured list with file:line, category, evidence, and reasoning. Severity is not yours to assign — just report findings with confidence levels.
```

Pass with `--read-only` and `--fresh` to ensure no edits and no resume of prior session.

## Validator spawn template

Validators see only one finding (or a batch from one file). They're allowed to read context outside the diff — that's the whole point.

**Single-finding validator:**

```
You are a code review validator. The pipeline flagged this potential issue. Your job: confirm it's real, or kill it.

FINDING UNDER REVIEW
--------------------

File: <path>
Line: <num>
Type: <category>
Evidence: "<quoted lines>"
Reasoning: "<claimed why-broken>"
Source agent: <bug-reviewer | claudemd-compliance-reviewer | ...>
Confidence reported: <high | medium>

CONTEXT
-------

Base SHA: <sha>
Changed files in the same PR: <list>

YOUR JOB
--------

1. Read the file in full (path above).
2. If the finding requires understanding callers or callees, follow up to 2 references.
3. Decide: is this finding real?
4. If real, assign severity:
   - blocker: will fail to build, crash at runtime, produce wrong output, or violate a hard CLAUDE.md rule
   - major: will cause incorrect or fragile behavior, drop an error path, miss a critical test, deviate from intent
   - suggestion: real but minor; would improve quality without being a must-fix
5. Return:
   ```
   {
     valid: true|false,
     severity: "<level>",
     file: "<path>",                   # REQUIRED — confirmed exact file path
     line_start: <N>,                  # REQUIRED — confirmed exact line number(s)
     line_end: <N>,                    # REQUIRED — equals line_start for single-line findings
     evidence: "<refined quote>",      # REQUIRED — exact quoted line(s) from the file
     refined_description: "<one-sentence>",
     reasoning: "<why valid/invalid>"
   }
   ```

CONSTRAINTS
-----------

- Read-only. No edits.
- If you cannot confirm with high confidence in 2 file reads, return valid: false with reasoning: "could not confirm".
- Apply the do-NOT-flag list from the parent pipeline (pre-existing issues, lint nits, etc.).
- **Citation is mandatory.** `file`, `line_start`, and `line_end` must be present for every `valid: true` finding. If the source agent didn't provide them, you must derive them by reading the file. The final output ships explicit `file:line` to the user — a finding without citation is a finding that gets dropped at merge.
```

**Batched-by-file validator** (when 2+ findings target the same file):

Same template, but `FINDING UNDER REVIEW` becomes a numbered list, and the return is an array of `{ finding_id, valid, severity, ... }` objects.

## Concurrency and read-only enforcement

All reviewer and validator agents inherit the `git-readonly-guard` hook through their frontmatter (the four custom reviewer agents) or via tool allowlist (the validators using `general-purpose` get `Read, Grep, Glob, Bash` — write tools are not included).

If a validator's needs exceed the read-only floor (e.g., it wants to run a linter), it should return `valid: false, reasoning: "needs more context than read-only permits"` and the orchestrator surfaces that as a gap to the user. Validators do not break the floor.

## Result merge format

Each agent returns findings. The orchestrator merges by:

1. Dedupe on `(file, line_range, type)` — same finding from multiple agents collapses, keeping the highest-confidence version and noting `discovered_by: [bug-reviewer, codex]`
2. Apply validator results — drop `valid: false`, attach severity from `valid: true`
3. Sort: blockers first (by file path), then majors, then suggestions
4. Pass to Phase 5 output formatter

Dedupe key tolerance: two findings count as the same when they're in the same file and their line ranges overlap (`max(start_a, start_b) <= min(end_a, end_b)`). Don't over-merge — if two agents flagged different aspects of the same line, keep both with a shared `cluster_id`.
