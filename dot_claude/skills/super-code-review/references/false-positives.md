# False Positives — Extended Catalog

The abridged "do NOT flag" list lives in SKILL.md. This file is the full catalog, used by validators in Phase 3 as the final filter before a finding ships.

## The cost of false positives

False positives are not free — they erode trust in every future review. A reviewer that ships even one bad finding will be quietly mistrusted on its good findings. The product is **high-signal output**; the false-positive filter is the load-bearing wall.

Rule: if a finding requires a paragraph of explanation to defend, it's a false positive. Real findings explain themselves.

## Always-false-positive categories

### Style / formatting / naming

These are linter territory. Even when CLAUDE.md mentions style, defer to the linter unless the rule is explicitly enforced by humans (e.g., "TODO must be attributed" is human-enforced; "use 2-space indent" is linter-enforced).

Examples not to flag:
- "Variable name `x` is unclear"
- "Inconsistent spacing"
- "Prefer `let` over `var`" (unless CLAUDE.md says exactly this)
- "Add a docstring"
- "Camel-case violation"

### Pre-existing issues

If the issue exists in the codebase but isn't introduced or moved by this diff, it's pre-existing. Out of scope.

Detection: when reviewing a finding, run `git blame <file> -L <line>,<line>` — if the line wasn't added by this diff's commits, it's pre-existing.

Exception: if the diff *amplifies* the impact of a pre-existing issue (e.g., the pre-existing function had one caller; this diff adds 20 more), then it's worth surfacing with a note that the issue is pre-existing but newly more important.

### Linter-catchable

If a linter (eslint, swiftlint, clippy, ruff, etc.) would catch the issue, don't flag it. The user has linters in CI for this. Specific examples:

- Unused imports
- Unused variables
- Trailing whitespace
- Line length violations
- `==` vs `===` in JS
- Missing semicolons

The reviewer doesn't have time to second-guess every linter rule. Trust the linter.

### Silenced-by-directive issues

If the issue is silenced by an in-code directive, the author already considered it. Don't flag.

Patterns:
- `// swiftlint:disable <rule>` / `// swiftlint:disable:next <rule>`
- `# noqa: <code>`
- `# type: ignore`
- `// @ts-ignore` / `// @ts-expect-error`
- `// eslint-disable-line <rule>` / `// eslint-disable-next-line <rule>`
- `#[allow(<lint>)]` in Rust
- `// nolint:<linter>`
- `# rubocop:disable <cop>`

Exception: a silenced violation without justification *can* be flagged by `shortcut-intent-reviewer` as a shortcut pattern (bypass-flag). That's a different concern than re-flagging the underlying issue itself.

### Subjective / preferences

If two reasonable engineers would disagree on whether something is wrong, it's a preference, not a bug. Skip.

Examples:
- "This function is too long"
- "Could be split into smaller functions"
- "Could use a different data structure"
- "Could be more functional / more imperative"
- "Prefer X pattern over Y pattern" (unless CLAUDE.md mandates)

### Speculative / state-dependent

If the issue only manifests under conditions you cannot verify from the diff, skip:

- "If this is called concurrently it might race" — unless the diff *introduces* the concurrency
- "If inputs are large this might be slow" — unless the diff *introduces* a performance regression on realistic inputs
- "If this is called before X is initialized" — unless the diff changes the initialization order
- "If the user passes negative values" — unless the diff removes a guard that handled them

The threshold: a real reviewer should be able to write the failing test or input. If it's purely hypothetical, skip.

### "You should also test X"

If X isn't part of the diff, don't flag missing tests for X. The test-thoroughness-reviewer flags missing tests for the **changed behavior**, not adjacent behavior.

Exception: if the diff *adds a code path* that has no test, that path is in-scope and missing tests are flaggable.

### Missing tests for trivial changes

The test-thoroughness-reviewer should NOT flag missing tests when the diff is:

- Pure rename (variable, function, type)
- Comment-only changes
- Whitespace / formatting changes
- Import order reshuffling
- Generated file updates (Cargo.lock, lockfiles)
- Documentation-only changes

The bar: changed *observable behavior* needs a test. Changed text-of-the-code-without-behavior does not.

### CLAUDE.md violations against non-scoped CLAUDE.md

The claudemd-compliance-reviewer must only flag against CLAUDE.md files that scope to the changed file. A `/repo/src/auth/CLAUDE.md` rule does not apply to `/repo/src/billing/foo.ts`.

This is the most common claude-md FP shape. Re-check scope before flagging.

### Findings the parent reviewer's role doesn't own

Each reviewer has a scope. Flagging outside the scope creates duplicate work and confusion.

- bug-reviewer does NOT flag style, missing tests, CLAUDE.md, TODOs
- claudemd-compliance-reviewer does NOT flag bugs, missing tests, TODOs
- test-thoroughness-reviewer does NOT flag style, CLAUDE.md, bugs (unless the bug *is* in a test file)
- shortcut-intent-reviewer does NOT flag style, missing tests, bugs

When a reviewer accidentally produces a cross-domain finding (it happens), the validator drops it as `valid: false, reasoning: "outside this reviewer's scope; the <other> reviewer would own it."`

### Pre-existing CLAUDE.md violations re-surfaced because the file moved

If a file was moved (e.g., `git mv`) and now sits in a more-scoped CLAUDE.md's path, the rules of that CLAUDE.md technically apply. But: don't flag pre-existing patterns the move *exposed*; only flag patterns the diff *introduced*.

## Validator final filter checklist

Before a validator returns `valid: true`, it must confirm:

1. ☐ The line(s) cited are added/modified by *this* diff (not pre-existing)
2. ☐ The issue isn't silenced by a directive on the same line or above
3. ☐ The issue isn't in the reviewer's scope only — it's actually the kind of issue this reviewer should be flagging
4. ☐ The evidence is quoted exactly from the diff
5. ☐ The reasoning is one sentence and would survive a code-review-of-the-code-review
6. ☐ The issue would matter to a senior engineer reviewing the diff
7. ☐ The finding doesn't require speculation about future state or hypothetical inputs

If any checkbox fails, return `valid: false` with the reason.

## When in doubt

When the validator is genuinely unsure: **kill it**. False negatives are recoverable (the user can find them later, or the next review catches them, or CI catches them). False positives are not — they consume the user's attention and erode trust per finding.

The skill's whole value proposition is that *every* finding is worth reading. Hold that line.
