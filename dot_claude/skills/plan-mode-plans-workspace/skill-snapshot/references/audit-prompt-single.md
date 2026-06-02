# Audit Prompt: Single-File Plans

Use this prompt when running Phase 4.5 against a plan that lives in a single `.md` file (single-session variant, with or without TDD).

If the plan uses TDD cycles, **also append the contents of `audit-prompt-tdd-additions.md`** to this prompt before sending it to the rescue agent.

Substitute the two bracketed paths (`<ABSOLUTE_PATH_TO_PLAN>`, `<ABSOLUTE_REPO_ROOT>`) with the real paths.

---

```markdown
Audit this implementation plan against the actual codebase. Do NOT modify any files (read-only review).

Plan file: <ABSOLUTE_PATH_TO_PLAN>
Repo root: <ABSOLUTE_REPO_ROOT>

Read the plan, then verify against the code:

1. **Self-containment**: Does the plan inline all syntax, signatures, and patterns needed? Does any step assume context a fresh session won't have?
2. **Code references**: Are file paths, function names, types, and line numbers accurate? Spot-check 5+ key references.
3. **Snippets**: Do the code snippets use real APIs from the repo or referenced libraries? Flag any wishful-thinking placeholders.
4. **Assumptions**: Are the listed assumptions actually true? Verify by reading code.
5. **Edge cases**: What edge cases or failure modes does the plan miss?
6. **Better alternatives**: Is there an obviously better approach the plan didn't consider? Mention only if material.

Group findings as:
- CRITICAL — plan would fail, produce broken code, or destroy data
- WARNING — gaps that would slow execution or risk bugs
- INFO — minor improvements, style

Cite file paths and line numbers exactly. Do NOT modify the plan or any source files.
```
