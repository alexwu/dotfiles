# Audit Prompt: Multi-File Plans (Agent Teams)

Use this prompt when running Phase 4.5 against a plan that lives in a directory (`plans/{name}/index.md` + numbered section files) — the agent-teams variant, with or without TDD.

If the plan uses TDD cycles, **also append the contents of `audit-prompt-tdd-additions.md`** to this prompt before sending it to the rescue agent.

Substitute the two bracketed paths (`<ABSOLUTE_PLAN_DIR>`, `<ABSOLUTE_REPO_ROOT>`) with the real paths.

---

```markdown
Audit this multi-file implementation plan against the actual codebase. Do NOT modify any files (read-only review).

Plan directory: <ABSOLUTE_PLAN_DIR>
Repo root: <ABSOLUTE_REPO_ROOT>

This plan is multi-file. Read `index.md` first, then section files in numbered order from the plan directory.

Verify against the code:

1. **Self-containment**: Does the plan inline all syntax, signatures, and patterns needed? Does any section assume context a fresh session won't have?
2. **Code references**: Are file paths, function names, types, and line numbers accurate across sections? Spot-check 5+ key references spanning multiple sections.
3. **Snippets**: Do code snippets use real APIs from the repo or referenced libraries? Flag any wishful-thinking placeholders.
4. **Assumptions**: Are the listed assumptions actually true? Verify by reading code.
5. **Edge cases**: What edge cases or failure modes does the plan miss?
6. **Cross-section consistency**: Do sections agree on shared decisions, file ownership, naming, and dependency order? Flag contradictions between index.md's Synthesis section and individual section files.
7. **Better alternatives**: Is there an obviously better approach the plan didn't consider? Mention only if material.

Group findings as:
- CRITICAL — plan would fail, produce broken code, or destroy data
- WARNING — gaps that would slow execution or risk bugs
- INFO — minor improvements, style

Cite file paths (including which section file) and line numbers exactly. Do NOT modify the plan or any source files.
```

**Important:** The audit happens AFTER teammate shutdown is *queued* in process flow but BEFORE it executes — the lead may still need to revise section files based on findings, and teammates are not involved in revision. The lead handles all audit-driven edits directly.
