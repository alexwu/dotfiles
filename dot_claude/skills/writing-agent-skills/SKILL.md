---
name: writing-agent-skills
description: Use when creating, writing, editing, scaffolding, or reviewing an Agent Skill — a SKILL.md skill for Claude Code, Codex, or any compatible agent. Covers structuring SKILL.md with progressive disclosure, writing or fixing the name/description frontmatter, splitting content into references/, deciding what belongs in a skill versus the agent's own judgment, bundling helper scripts or justfile recipes, calibrating how prescriptive instructions should be, optimizing a description so it triggers reliably, and building eval sets that test both triggering and output quality. Triggers on "create a skill", "write a SKILL.md", "my skill won't trigger", "improve this skill's description", "evaluate my skill", "review this skill", or any work under a skills/ directory — even when the user is clearly authoring an agent capability without saying "skill". Follows the agentskills.io specification.
---

# Writing Agent Skills

A skill is a directory with a `SKILL.md` file. The agent reads only its `name` + `description` at startup, then loads the full body **on demand** when a task matches. Everything in this skill flows from that one fact: **context is the budget you are spending, and the description is the trigger that earns the spend.**

## The shape (non-negotiable)

```
skill-name/
├── SKILL.md          # required: frontmatter + core instructions
├── references/       # optional: load-on-demand deep dives
├── scripts/          # optional: bundled, tested helpers
└── assets/           # optional: templates, schemas, data
```

Three tiers of progressive disclosure — keep each in its lane:

| Tier | Loaded | Budget | Holds |
|------|--------|--------|-------|
| Metadata (`name`+`description`) | always, every skill | ~100 tokens | the trigger |
| `SKILL.md` body | on activation | **< 500 lines / < 5k tokens** | core procedure + always-needed facts |
| `references/`, `scripts/`, `assets/` | only when SKILL.md tells the agent to | unbounded | depth, edge cases, templates |

If a fact is needed on *every* run, it goes in `SKILL.md`. If it's needed only *sometimes*, it goes in a reference — and you must tell the agent **the trigger condition** for loading it ("Read `references/api-errors.md` when the API returns non-200"), never a generic "see references/ for details."

## Frontmatter cheat-sheet

| Field | Required | Constraint |
|-------|----------|-----------|
| `name` | yes | 1–64 chars, `[a-z0-9-]`, no leading/trailing/double hyphen, **must match the directory name** |
| `description` | yes | 1–1024 chars; says **what it does AND when to use it**; this is the only trigger signal |
| `license` | no | short license name or bundled file reference |
| `compatibility` | no | ≤500 chars; only if the skill needs specific tools/runtime/network |
| `metadata` | no | arbitrary string→string map |
| `allowed-tools` | no | space-separated pre-approved tools (experimental, support varies) |

Full field semantics, validation, and file-reference rules: `references/specification.md`.

## Authoring principles (apply every time)

1. **Start from real expertise, not the model's priors.** A skill generated from "best practices for X" is vague filler. Ground it in a real task you actually drove — the corrections you made, the conventions the agent *didn't* know, the gotchas that bit you. Synthesize from real artifacts (runbooks, PR comments, fixes), not generic articles.
2. **Add what the agent lacks; omit what it knows.** For each line ask: *"Would the agent get this wrong without this instruction?"* If no, cut it. Don't explain what a PDF is or how HTTP works. Spend the budget on project-specific conventions, non-obvious edge cases, and which tool/API to reach for.
3. **Provide defaults, not menus.** Pick one tool, mention the escape hatch briefly. "Use X. For the OCR case, use Y instead." — never "you could use A, B, C, or D."
4. **Favor procedures over declarations.** Teach *how to approach a class of problems*, not *what to output for one instance*. The method should generalize even when individual details are specific.
5. **Calibrate control to fragility.** Loose, reasoned guidance where many approaches work ("explain *why*, the agent decides"); rigid, exact sequences where the operation is fragile or order-critical ("run exactly this, do not add flags"). Most skills mix both — calibrate each section independently.
6. **Moderate detail beats exhaustive.** Concise stepwise guidance + one working example outperforms covering every edge case. When you're documenting the 12th edge case, ask whether the agent's own judgment handles it.

## Workflow

1. **Draft** — write `SKILL.md` from a real task. Lean body, defaults over menus, one worked example.
2. **Refine with real execution** — run it on real tasks and read the *execution traces*, not just outputs. Vague instructions show up as the agent trying several approaches; inapplicable instructions show up as the agent following them anyway; too many options show up as thrash. Feed all of it — successes included — back into a revision. When the agent makes a mistake, add the correction to a **Gotchas** section. One execute-then-revise pass already helps a lot.
3. **Validate & deploy** — see below.

**Optional — structured evaluation (opt-in, never a default).** The formal eval loops are heavyweight: they spawn many agent runs and spend real time and tokens. Treat running them as a deliberate step the user chooses, not an automatic part of authoring — **offer it and confirm before running either one**:

- *Trigger-rate eval* — measure whether the `description` fires on the right prompts and only those → `references/optimizing-descriptions.md`.
- *Output-quality eval* — a with-skill vs. without-skill harness proving the skill earns its context → `references/evaluating-skills.md`.

Writing a sharp description and reading execution traces (steps 1–2) are always worthwhile; the *formal harnesses* above are the part you opt into.

## High-value content patterns

Pull these in as they fit — full examples in `references/best-practices.md`:

- **Gotchas section** — environment-specific facts that defy reasonable assumptions ("the `users` table uses soft deletes; queries must include `WHERE deleted_at IS NULL`"). The single highest-value thing in most skills. Keep gotchas in `SKILL.md`, not a reference — the agent must read them *before* hitting the situation.
- **Output templates** — agents pattern-match concrete structures better than prose descriptions. Short → inline; long/conditional → `assets/`.
- **Checklists** for multi-step workflows with dependencies or gates.
- **Validation loops** — do work → run a validator → fix → repeat until it passes.
- **Plan-validate-execute** for batch/destructive ops — emit a structured plan, validate it against a source of truth, *then* execute.

## Reference map (load on demand)

- `references/specification.md` — full SKILL.md format: every frontmatter field, directory roles, progressive-disclosure rules, file-reference conventions, validation. **Load when** writing frontmatter, unsure of a constraint, or structuring directories.
- `references/best-practices.md` — grounding skills in real expertise, spending context wisely, calibrating control, and the full pattern library (gotchas, templates, checklists, validation loops, plan-validate-execute, bundling). **Load when** drafting or substantially revising a skill body.
- `references/optimizing-descriptions.md` — making the `description` trigger reliably: writing principles, building trigger eval sets, measuring trigger rate, train/validation splits, the optimization loop. **Load when** a skill fires too rarely, too often, or you're hardening a new description. *Running the formal loop is opt-in — confirm first.*
- `references/evaluating-skills.md` — output-quality evals: test cases, with/without-skill runs, assertions, grading, aggregation, iteration. **Load when** a skill matters enough to measure, or you're comparing two versions. *Running the harness is opt-in — confirm first.*
- `references/using-scripts.md` — when to bundle a script vs. inline a command, the **language policy** for this environment, organizing helper commands as `just` recipes, and designing scripts for agentic use (no interactive prompts, `--help`, structured output, exit codes). **Load when** a skill needs bundled executable logic.

## Validate & deploy

- Sanity-check naming/frontmatter against `references/specification.md`: `name` matches the directory, `description` is ≤1024 chars, required fields present, body under the line/token budget.
- A skill lives in a directory the agent scans (e.g. `~/.claude/skills/`, a project `.claude/skills/`, or `.agents/skills/`, depending on the client). After adding or editing one, start a fresh session — or reload skills if the client supports it — so the change is picked up.
