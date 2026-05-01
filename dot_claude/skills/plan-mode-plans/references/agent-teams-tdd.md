# Agent Teams + TDD (variant deltas)

Loaded only when BOTH `agent-teams.md` and `tdd-cycles.md` apply. This file contains ONLY the deltas — anything that's already in those two references is not repeated here.

## Test Infrastructure Teammate (Phase 1 addition)

**Recommended** (not required) when:
- The project has complex test setup (custom runners, shared fixtures, CI-specific config)
- Multiple section files need to reference the same test helpers
- New test utilities need to be created for this task

When included, the test infrastructure teammate:
- **Explores:** test framework config, shared helpers/factories/fixtures, CI test commands, coverage tooling, mock/stub patterns (or request recording tools like VCR/OHHTTPStubs)
- **Writes their section as `01-test-infrastructure.md`** — first in order, since other sections depend on it
- **Other teammates' section-drafting tasks should depend on this section** (via `addBlockedBy` in `TaskUpdate`) so they can reference discovered test helpers and conventions

## Phase 2 Spawn Prompt: TDD Addition

In addition to the universal exploration standards from `agent-teams.md`, every teammate spawn prompt MUST also instruct teammates to:
- **Identify test framework, runner, test file conventions, helpers, fixtures, and existing test patterns** (TDD-specific exploration)

And the Exploration Red Flags list extends with:
- **TDD-specific:** You don't know the test command, test file naming pattern, or available helpers

## Phase 3 Addition: Mocking Decisions

When clarifying with the user, also surface:
- **Mocking decisions** — do not use mocks unless the user explicitly approves. If the project uses request recording tools (VCR, OHHTTPStubs, etc.), use those instead. Ask here if unsure.

## index.md Section Map (TDD example)

When a test-infra teammate is included, the Section Map in `index.md` typically looks like:

```markdown
## Section Map
| # | Section | File | Owner | Status |
|---|---|---|---|---|
| 1 | Test Infrastructure | 01-test-infrastructure.md | test-explorer | Complete |
| 2 | Data Layer | 02-data-layer.md | data-layer-explorer | Complete |
| 3 | API Routes | 03-api-routes.md | api-explorer | Complete |
```

The Verification section in `index.md` should explicitly note that `coderabbit review --agent` runs over the **cumulative diff after all cycles in all sections complete**, not per-cycle.

## Lead Review Gates (TDD additions)

In addition to the universal Lead Review Gates from `agent-teams.md`:

| Check | Fail Condition | Action |
|---|---|---|
| TDD format | Missing RED/GREEN verify commands or expected failure | Create revision task via `TaskCreate` |
| Cycle granularity | Cycle tests multiple behaviors | Create revision task — split it |
| Test commands | Inconsistent test commands across sections | Standardize against test infra section |

## Self-Containment Test (multi-file TDD additions)

In addition to checks in `agent-teams.md` and `tdd-cycles.md`:

- If a test infrastructure section exists, do other sections reference its helpers correctly?
- Does index.md's Verification section call out `coderabbit review --agent` over the cumulative diff after all cycles in all sections complete?

## Common Mistakes (multi-file TDD specific)

In addition to mistakes in `agent-teams.md` and `tdd-cycles.md`:

| Mistake | Fix |
|---|---|
| No test infra teammate, sections invent different patterns | Add a test infra teammate or have lead standardize in index.md |
| Section TDD cycles reference helpers from an unimplemented section | Use Dependencies to order implementation. Test infra goes first. |
| Skipped Phase 4.5 audit on a multi-section TDD plan | Default is run. Multi-file TDD plans benefit *most* — RED messages, test paths, and cycle ordering are easy to get subtly wrong. Only skip when user explicitly says so. |
| Audit prompt missing TDD-specific checks | Append `audit-prompt-tdd-additions.md` to `audit-prompt-multifile.md` before invoking the audit. |
