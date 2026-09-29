# Agent Spawn Prompt Templates

How the orchestrating skill assembles spawn prompts for the reviewers and validators. Each prompt must be **self-contained** — the spawned subagent doesn't see the orchestrator's conversation history.

## Reviewer spawn template (used for all five generic reviewers + Codex)

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

PASS CONTEXT
------------

Pass: <n> of <cap> (<full | incremental | closing>)
Delta since the last reviewed pass (<line | file | whole>): <inline delta, or "See file: <path>">

Findings from the last pass, including threads this review opened
(being re-checked separately; don't re-report them):
<numbered list: file:lines — title — severity, or "(none)">

Other feedback on the PR (threads, review bodies, conversation comments):
<numbered list: kind — file:lines — author — open/resolved — first and last comment excerpts — url, or "(none)">

Review the whole diff and report everything you find. Mark each finding
`in_delta: true|false`. When the latest changes broke behavior that
worked before, add `regression: true`. If a finding repeats other
feedback, report it anyway and add `matches: <url>`; the orchestrator
decides what to repost.

DIFF
----

<either inline diff if <50 KB, or "See file: <path to the diff file from diff-sources.md>">

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

Open the prompt with `--model gpt-6-astra --effort high --fresh --read-only`; see `codex-second-opinion.md` → "Forwarding flags".

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
Rule source: <path> (claude-md and TODO-attribution findings only)
Rule quote: "<verbatim rule>" (same)
Rule scope: <repo | user> (same)

CONTEXT
-------

Base SHA: <sha>
Changed files in the same PR: <list>

YOUR JOB
--------

1. Read the file in full (path above).
2. If the finding requires understanding callers or callees, follow up to 2 references.
3. Decide: is this finding real?
4. If real and `Rule scope` is `user`, assign no severity — set `severity: "none"`. It's a local note, never posted (see claude-md-integration.md → "User-level rules stay local"). Otherwise, assign severity:
   - blocker: will fail to build, crash at runtime, produce wrong output, violate a hard CLAUDE.md/AGENTS.md rule, or leave the diff's core behavior or a common edge case untested
   - major: will cause incorrect or fragile behavior, drop an error path, deviate from intent
   - A missing test for an obscure edge case, or an incidental extra test case, isn't a finding: return valid: false
   - suggestion: real but minor; would improve quality without being a must-fix
   - The bar: blocker or major only when the change leaves the code worse than the base. A real improvement that could go further is a suggestion. When several designs are valid, the author's choice isn't a finding. Over-engineering against the stated intent is a major.
   - Set `regression: true` only when the latest changes broke behavior that worked before; confirm or reject the reviewer's claim.
5. Return:
   ```
   {
     valid: true|false,
     severity: "<level>",              # "none" when rule_scope is user
     regression: true|false,
     rule_scope: "repo|user",          # carried through unchanged when the finding has one
     in_delta: true|false,             # carried through unchanged
     origin: "new|carried",            # carried through unchanged
     matches: "<url>|null",            # carried through unchanged
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

## Carried-finding re-check template

On pass 2 and later, one agent per file re-checks the last pass's findings (`passes.md` → "Carried-finding re-checks"). Spawn it like a validator (`general-purpose`, `model` set: `opus` when any finding in the batch is a bug or silent-failure finding, `sonnet` otherwise).

```
You are re-checking findings from an earlier review pass. The code may have
changed since. For each finding, decide whether it's still there.

SOURCE
------
Mode: <pr | range | working>
Head SHA: <full sha or "working-tree">
Read the file as the review sees it: in working mode, the file on disk;
otherwise `git show <head>:<path>`, or `gh api` when the head isn't local.

FINDINGS FROM THE LAST PASS
---------------------------
<numbered list; for each: id, file, line_start-line_end, severity, title, evidence (quoted) as it was>

YOUR JOB
--------
For each finding:
1. Find the code it describes. Lines move between passes; search by the
   quoted evidence and the surrounding function, not the old line numbers.
2. Decide: `fixed` (the problem is gone), `still-open` (it's still there),
   or `regressed` (the fix broke behavior that worked before).
3. Return a JSON array, one object per finding:
   { "id": "<id>", "status": "fixed|still-open|regressed",
     "file": "<path>", "line_start": N, "line_end": N,
     "evidence": "<exact quoted line(s) as they are now>",
     "reasoning": "<one or two sentences>" }

CONSTRAINTS
-----------
- Read-only. No edits.
- Keep the old severity; don't re-grade.
```

A `regressed` result goes through normal validation as a new finding with `regression: true` and `origin: "carried"`.

## Fable validator template (`--submit`)

Spawn with `subagent_type: "general-purpose"` and `model: "fable"`, after Phase 4. One agent for up to 15 findings; above that, split by file across parallel agents. See `submit.md` for what happens with the result.

```
You are the final validator before a pull-request review is submitted under the user's name. The review pipeline produced the findings below. Your job: confirm each one is real, and kill any that isn't. A finding you keep may block a merge, so hold every one to that bar.

PR
--
Repo: <owner/repo>
PR: #<number> — <title>
Head SHA: <full sha>
Pass: <n> of <cap> (<full | incremental | closing>)
Diff: <path to the diff file>
Changed files: <list>

FINDINGS
--------
<numbered list; for each: id, file, line_start-line_end, severity, type, evidence (quoted), description, in_delta, origin (new | carried), regression, rule_source/rule_quote and matches when present>

YOUR JOB
--------
For each finding:
1. Read the cited file in full at the head commit, and follow up to 2 callers or callees when the claim depends on them.
2. Decide whether it's real, introduced by this diff, and something a senior reviewer would block on or ask to fix. Apply the do-NOT-flag list: pre-existing issues, linter-catchable nits, style preferences, speculative "could race" concerns the diff doesn't introduce, anything silenced by a directive.
3. Confirm the severity: blocker (breaks the build, crashes, wrong output, violates a hard repo rule, leaves the diff's core behavior or a common edge case untested), major (fragile or incorrect behavior, a dropped error path, drift from the stated intent), or suggestion. You may change it; say why. A missing test for an obscure edge case, or an incidental extra test, isn't a finding: kill it. The bar: blocker or major only when the change leaves the code worse than the base. A real improvement that could go further is a suggestion. When several designs are valid, the author's choice isn't a finding. Over-engineering against the stated intent is a major. Confirm or reject `regression`: true only when the latest changes broke behavior that worked before.
4. Check the cited lines against the diff: `inline: true` when every cited line is on the new (right-hand) side of a diff hunk, `inline: false` otherwise.

Return a JSON array, one object per finding:
{ "id": "<id>", "keep": true|false, "severity": "blocker|major|suggestion",
  "severity_changed_because": "<reason or null>", "regression": true|false,
  "inline": true|false,
  "file": "<path>", "line_start": N, "line_end": N,
  "evidence": "<exact quoted line(s)>", "reasoning": "<one or two sentences>" }

CONSTRAINTS
-----------
- Read-only. No edits, no writes, no git or gh commands that change anything.
- When you can't confirm a finding, kill it. A false blocker on someone's PR costs more than a missed nit.
```

Fable returns severity and `regression`; the orchestrator, not Fable, derives `blocking` from them (SKILL.md → "Severity and blocking").

## Concurrency and read-only enforcement

The five custom reviewer agents carry the `git-readonly-guard` hook in their frontmatter. Validators run as `general-purpose`, which has every tool, including Edit and Write; the Agent tool can't narrow that per spawn. The `Read-only. No edits.` constraint in the validator template is the only thing holding them read-only, so keep it in every validator prompt.

Domain auditors (`axiom:*`) are plugin agents with their plugin's own tool set and no guard hook. The spawn prompt is the only read-only constraint on them, so say so in it.

Always pass `model` on validator spawns. Without it, `general-purpose` inherits the session model.

If a validator's needs exceed the read-only floor (e.g., it wants to run a linter), it should return `valid: false, reasoning: "needs more context than read-only permits"` and the orchestrator surfaces that as a gap to the user. Validators do not break the floor.

## Result merge format

Each agent returns findings. The orchestrator merges by:

1. Dedupe on `(file, line_range, type)` — same finding from multiple agents collapses, keeping the highest-confidence version and noting `discovered_by: [bug-reviewer, codex]`
2. Apply validator results — drop `valid: false`, attach severity from `valid: true`
3. Partition `rule_scope: user` findings into `user_rule_notes`. They never enter `findings[]`, the severity counts in `stats`, or any output that reaches the PR
4. Sort the remaining findings: blockers first (by file path), then majors, then suggestions
5. Pass to Phase 5 output formatter

Dedupe key tolerance: two findings count as the same when they're in the same file and their line ranges overlap (`max(start_a, start_b) <= min(end_a, end_b)`). Don't over-merge — if two agents flagged different aspects of the same line, keep both with a shared `cluster_id`.
