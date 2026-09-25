# Audit Prompt Additions: TDD-Structured Plans

Append this block to either `audit-prompt-single.md` or `audit-prompt-multifile.md` when the plan uses TDD cycles (RED/GREEN/REFACTOR steps). Composition and renumbering rules: `audit-prompts.md`.

---

```markdown
TDD-specific additional checks:
- **RED expected-failure messages** match the test framework's actual error format (e.g., compiled languages may surface "use of unresolved identifier" before runtime "function not defined")
- **Test file paths and helpers** in cycles match the repo and the test-infra section's conventions
- **Commit messages** follow the project's conventional-commit style
- **GREEN snippets are minimal** — they implement only what the current RED test demands, not future cycles' work
- **Cycle ordering** is correct — happy path first, edges next, errors last, integration last
- **Test infra dependencies** (multi-file only) are honored — sections that reference helpers from `01-test-infrastructure.md` should declare it in `Depends on:`
```
