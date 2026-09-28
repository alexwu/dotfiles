---
name: super-code-review
description: |
  Multi-agent code review of a GitHub PR, a local commit range, or uncommitted working-tree changes. Parallel reviewers cover bugs, silent failures, CLAUDE.md/AGENTS.md compliance, test thoroughness, and shortcuts/scope drift, plus a Codex second opinion; every finding is validated before it ships. With `--submit`, a Fable pass re-validates the findings and the skill approves the PR or requests changes. Effort tiers low/medium/high, with domain routing for Swift/iOS. Use for any review request, even without the word "super": "review this PR", "code review", "review #123", "review and approve", "look over my changes", "audit this branch", "review my working tree", "check my staged changes". Supersedes `/code-review`, `pr-review-toolkit:review-pr`, `feature-dev:code-reviewer`, `coderabbit:code-review`, `simplify`, and `security-review`. CodeRabbit runs only with `--coderabbit`.
---

# super-code-review

A high-confidence code reviewer with structured validation. The pipeline is opinionated: parallel reviewer fan-out + Codex second opinion + per-finding validation pass before anything reaches the user.

## When this skill applies

- The user asked for a review of a PR, branch, commit range, or working tree
- The user wants a deep audit before merging / committing / pushing
- The user mentioned any reviewer-style flag: `--comment`, `--effort`, `--coderabbit`

When in doubt: it applies. The pushy description above is intentional — this skill is meant to be the *only* review entry point.

## Args

| Flag | Default | Purpose |
|---|---|---|
| `--source <auto\|pr\|range\|working>` | `auto` | Diff source mode |
| `--range <spec>` | — | Explicit range — `main...HEAD`, `HEAD~5..HEAD`, `pr:1234`, or `working` |
| `--effort <low\|medium\|high\|ultra>` | `high` | Pipeline depth |
| `--coderabbit` | off | Chain `coderabbit:code-review` after our pass |
| `--skip-codex` | off | Skip the Codex second opinion at `high`; everything else runs as usual |
| `--comment` | off | Post inline comments (PR mode only) |
| `--submit` | off | After the review, a Fable agent re-validates the findings, then the skill approves the PR or requests changes (PR mode only). See `references/submit.md` |
| `--block-on <major\|all>` | `major` | With `--submit`: which surviving findings trigger request-changes. `major` = blockers and majors; `all` = everything |
| `--json` | off | Machine-readable output |
| `--intent <list>` | `auto` | Comma list: `pr,issue,bd,plan,all,none` |

Auto-resolution (when `--source=auto`):
1. Try `gh pr view --json state` on current branch — if it returns a PR, use PR mode
2. Else if branch has commits ahead of the default branch (`git rev-list --count <default>..HEAD > 0`), use range mode with `<default>...HEAD`
3. Else if the working tree has staged, unstaged, or untracked changes (`git status --porcelain` is non-empty), use working-tree mode
4. Else: nothing to review — return early with that message

See `references/diff-sources.md` for details on each mode and exact commands.

## Pipeline (canonical: `--effort=high`)

The pipeline runs **read-only**: no edits, no writes, no pushes. The custom reviewers' `Bash` is guarded by `git-readonly-guard`; validators and domain auditors are held to it only by their spawn prompt.

### Phase 1 — Gather

In parallel (one message, multiple tool calls):

1. **Resolve diff source** → unified diff string + changed file list + base SHA
2. **Gather intent context** — pull PR body, linked GH issues, beads (`bd`) issues, plan files. See `references/intent-sources.md`
3. **Detect domain profile** — glob for `.xcodeproj`, `Package.swift`, `Cargo.toml`, `*.nimble`, `tsconfig.json`, etc. See `references/domain-routing.md` for the language → skill table

### Phase 2 — Reviewer fan-out (parallel)

Spawn these agents in a single message:

- `bug-reviewer` — Opus, logic/type/runtime bugs in the diff
- `silent-failure-reviewer` — Opus, swallowed errors, fallbacks that hide failures, discarded Results
- `claudemd-compliance-reviewer` — Sonnet, violations of scoped instruction files: `CLAUDE.md`, `AGENTS.md`, or both, whichever the repo uses. See `references/claude-md-integration.md` for discovery
- `test-thoroughness-reviewer` — Sonnet, test coverage + smell audit
- `shortcut-intent-reviewer` — Sonnet, TODO/HACK markers + scope drift vs. intent
- **Domain reviewers** (conditional, based on profile detection):
  - iOS / Swift: `axiom:swiftui-architecture-auditor`, `axiom:concurrency-auditor` (if async touched), `axiom:swiftdata-auditor` / `axiom:core-data-auditor` (if persistence), `axiom:testing-auditor` (if tests), etc. — see `references/domain-routing.md` for the full mapping
  - Generic: skip
- `codex:codex-rescue` — **second opinion**, read-only Codex review. See `references/codex-second-opinion.md` for exact invocation. Run in parallel with our reviewers, not after. Not spawned when `--skip-codex` is passed.

Each reviewer receives a self-contained spawn prompt with:
- The diff (inline if <50 KB, else as a file path)
- The list of changed file paths
- The intent context (PR body / issue text / bd / plan excerpts)
- The detected domain profile
- The source mode and base SHA

### Phase 3 — Validation

Take all findings from Phase 2. For each unique finding (dedupe by `file:line:type`):

Spawn a validator subagent (`general-purpose`, with `model` set explicitly: `opus` for bug and silent-failure findings, `sonnet` for the rest — an unset model inherits the session's). Validators are **allowed to read context outside the diff** — that's the whole point of validation. The validator's job:

1. Confirm the finding is real (re-read the relevant file, trace call sites if needed)
2. Assign a severity: `blocker` / `major` / `suggestion`
3. Return: `valid: true|false`, `severity`, `evidence`, `refined_description`

Batch validators by file when 2+ findings hit the same file — single read, multiple confirmations. See `references/agent-prompts.md` for the validator template.

### Phase 4 — Merge

- Drop validators' `valid: false` findings
- Move `rule_scope: user` findings into `user_rule_notes` — local only, never in `findings[]`, severity counts, or anything posted
- Dedupe across our reviewers + Codex (often two agents flag the same thing — keep the higher-confidence version)
- Sort by severity, then file path

### Phase 5 — Output

See `references/output-formats.md` for the exact formats. Three modes:

- **Default** — terminal summary, ranked by severity, with file:line citations
- **`--comment`** — post inline comments to the PR using the strict SHA / L4-7 / repo-match format. **Only ONE comment per unique issue.**
- **`--json`** — machine-readable structured output

### Phase 5b — Submit (`--submit`)

Runs after the local output, in PR mode only. Follow `references/submit.md` exactly:

1. A `general-purpose` agent with `model: "fable"` re-validates every merged finding (not the user-rule notes).
2. Any kept finding at or above `--block-on` → submit `REQUEST_CHANGES` with those findings inline. None → submit `APPROVE`. On the user's own PR, submit `COMMENT` and state the verdict it would have been.
3. Every posted word is written under the `writing-english` skill; load it before writing.
4. If the Fable pass can't run, or the PR head moved during the review, don't submit.

### Phase 6 — Optional CodeRabbit

If `--coderabbit` was passed: after Phases 1-5 finish, invoke `coderabbit:code-review` and append its findings to the output. CodeRabbit is async on PRs — for local diffs it may be a no-op; the user is warned.

## Effort tiers

| Tier | Phase 2 reviewers | Codex 2nd opinion | Validation pass | Use case |
|---|---|---|---|---|
| `low` | bug-reviewer only | no | no | Quick sanity check on uncommitted work |
| `medium` | bug + silent-failure + claudemd + shortcut/intent | no | yes (lightweight, batched aggressively) | Pre-commit review |
| `high` (default) | All five + domain reviewers | yes | yes (full) | PR review, branch finalization |
| `ultra` | Defers to harness `/code-review ultra` | — | — | Billed cloud multi-agent pass |

See `references/effort-tiers.md` for the exact recipe per tier.

`--effort=ultra` cannot be launched from within this skill (the harness owns it and bills separately). Instead, output: "Effort=ultra delegates to the built-in harness command. Run `/code-review ultra` directly." Then stop.

## Severity tags

- **blocker** — must be fixed before merge: bugs that will crash/produce wrong output, violations of hard rules in CLAUDE.md/AGENTS.md, dropped error paths, a missing test for the diff's core behavior or a common edge case
- **major** — should be fixed: shortcut markers without tracking, scope drift, weak/tautological tests, soft CLAUDE.md/AGENTS.md violations
- **suggestion** — would be nice: stylistic things only flagged because a domain auditor caught them; second-opinion-only findings the validator confirmed but didn't promote

Validators assign severity; the main agent doesn't override.

Findings sourced only from a user-level file (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) get no severity. They're local notes to the user and are **never** posted to a PR. See `references/claude-md-integration.md` → "User-level rules stay local".

## The "do NOT flag" list (inline because load-bearing)

This list is the load-bearing trust-protector inherited from the prior `/code-review:code-review` skill. Every reviewer and validator must respect it. **Reviewers have their own scoped versions in their agent files; this is the merged-output filter.**

- Pre-existing issues outside the diff
- Pedantic nitpicks a senior engineer wouldn't flag
- Issues a linter would catch (don't run linters)
- General code quality concerns unless CLAUDE.md or AGENTS.md explicitly requires them
- Issues silenced by an in-code comment / directive (`// swiftlint:disable`, `# noqa`, `@ts-expect-error`, etc.)
- Speculative concerns ("could race if called concurrently") unless the diff introduces that risk
- Style/formatting/naming preferences
- "You should test X" when X isn't in the diff
- Missing tests for trivial changes (renames, comment edits, formatting-only)
- Missing tests for obscure edge cases, or incidental tests that only add another case to an already-covered path

If a finding can't survive this filter after validation, it does not ship.

## Inline-comment format (when `--comment` is used)

Inherited verbatim from the prior skill — these details matter because GitHub markdown rendering is unforgiving:

- **Load the `writing-english` skill before writing any comment.** Posted text goes out under the user's name; write it under that skill's rules, and keep pipeline details (reviewer names, local paths) out of it

- Use `mcp__github_inline_comment__create_inline_comment` with `confirmed: true` if the MCP server is available; else fall back to `gh api` per `references/output-formats.md`
- Code links must use full git SHA: `https://github.com/owner/repo/blob/<full-sha>/path/to/file#L4-L7`
- `L[start]-L[end]` line range — provide at least 1 line of context before and after
- Repo name in the URL must match the PR's repo
- For self-contained fixes (≤5 lines, single location), include a committable `suggestion` block
- For larger fixes, describe the issue + direction without a suggestion block — committable suggestions only when the suggestion *fully* fixes the issue
- **One comment per unique issue.** Duplicates are not allowed.
- **Never** post a finding sourced only from a user-level instruction file.

## Reference files

Load these as needed — they're sized for progressive disclosure:

- `references/diff-sources.md` — exact commands for PR / range / working-tree mode
- `references/effort-tiers.md` — recipe per tier
- `references/intent-sources.md` — PR body, gh issue, bd issue, plan file gathering
- `references/domain-routing.md` — language → skill / auditor table
- `references/test-thoroughness.md` — extended smell catalog (shared with the test-thoroughness-reviewer agent)
- `references/shortcut-detection.md` — extended pattern catalog (shared with the shortcut-intent-reviewer agent)
- `references/claude-md-integration.md` — when/how to invoke `claude-md-improver` and `decompose-claude-md`
- `references/codex-second-opinion.md` — exact `codex:codex-rescue` invocation
- `references/coderabbit-flag.md` — `--coderabbit` gating + chaining
- `references/output-formats.md` — terminal / inline / json schemas
- `references/submit.md` — `--submit` / `--block-on`: Fable validation, the approve / request-changes decision, payload, errors. **Load whenever `--submit` is passed**
- `references/agent-prompts.md` — validator and reviewer spawn-prompt templates
- `references/false-positives.md` — extended don't-flag catalog (the inline list above is the abridged version)

## What this skill does NOT do

- It does not fix issues — it reports, and with `--submit` it approves or requests changes. Auto-fix is a separate skill (`/simplify` flow, not part of this one).
- It does not run linters or compilers. CI is the place for that.
- It does not edit files. The five custom reviewers enforce this with a `git-readonly-guard` frontmatter hook; `general-purpose` validators and plugin domain auditors have write tools available and are held read-only by their prompt.
- It does not gate on "already reviewed" — the user invokes this skill explicitly; re-runs are intentional, not duplicate.

## Failure modes

- **No diff** — return early with a one-line message
- **`gh` not authenticated** in PR mode — explain and suggest `gh auth login`
- **Codex unavailable** (returns nothing) — proceed without the second opinion, note it in the output
- **MCP inline-comment server unavailable** in `--comment` mode — fall back to `gh api` (see `references/output-formats.md`)
- **`--submit` outside PR mode** — ignore it with a one-line warning; print the review as usual
- **Fable validation unavailable, or the PR head moved** under `--submit` — print the review, submit nothing, and say why
- **Domain auditor missing** — skip it, and name the expected-but-unavailable auditor in the output so a disabled plugin doesn't pass for a clean audit
