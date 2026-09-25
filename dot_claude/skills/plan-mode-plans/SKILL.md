---
name: plan-mode-plans
description: Use when entering plan mode (EnterPlanMode) to explore a codebase and write a specific, actionable implementation plan for user approval. Make sure to use this skill whenever the user enters plan mode, OR proactively when a task touches 3+ files, makes architectural choices, modifies subsystem boundaries, refactors across modules, or implements a feature spanning multiple layers — even if the user didn't explicitly say "plan". Covers single-session plans, TDD-structured plans, agent-team-driven multi-file plans, and combinations — variant selection is automatic based on task shape.

---

# Plan Mode Plans

## Overview

Write specific, actionable, **self-contained** plans in plan mode. The plan must be usable by a fresh session with zero prior context — if you looked something up during exploration, the findings go **in the plan**.

**Core principle:** Explore first, plan second. If you haven't read the files, you can't plan the changes. If the context isn't in the plan, it doesn't survive context clearing.

## Variant Selection (read FIRST)

This skill covers four variants. Pick based on the task shape, then load the matching reference files alongside this SKILL.md.

| Task shape | TDD requested? | Variant | Load these references |
|---|---|---|---|
| 1–2 focused areas, single session | No | **Single** (default) | `references/single-session.md` |
| 1–2 focused areas, single session | Yes | **TDD (single)** | `references/single-session.md` + `references/tdd-cycles.md` |
| 3+ independent areas, agent team | No | **Agent Teams** | `references/agent-teams.md` |
| 3+ independent areas, agent team | Yes | **Agent Teams + TDD** | `references/agent-teams.md` + `references/tdd-cycles.md` + `references/agent-teams-tdd.md` |

How to decide:
- **Areas**: count distinct subsystems / layers / domains the task touches based on initial read. 3+ → agent teams. (See `references/agent-teams.md` Decomposition Strategies for examples.)
- **TDD**: load TDD references only if the user explicitly asked for TDD-structured plans, OR the project has strong TDD culture confirmed during exploration. Don't impose TDD on a project that doesn't already use it.

If you're unsure, default to Single. Switch variants mid-planning if the task shape changes — it's cheaper to reload references than to write the wrong kind of plan.

## Process Flow

1. **Identify scope** (Phase 1).
2. **Explore** until you have enough context (Phase 2), then **clarify** with the user until nothing is left to ask (Phase 3).
3. **Draft** the plan and write it to the plan file (Phase 4). A draft that isn't specific enough sends you back to exploration.
4. **Audit** in parallel (Codex + Opus escalation), revise, and re-audit at most once. Then record the outcome and run `check-plan --fix` until it passes (Phase 4.5).
5. **Ask the compaction question**, then call `ExitPlanMode` (Phase 5).
6. **Post-approval handoff**: file beads and honor the compaction choice before any implementation (Phase 6).

## Phase 1: Identify Scope

Before reading anything, state:
- **What** needs to change (feature/fix/refactor)
- **Where** it likely lives (educated guess from project structure)
- **What you don't know** yet (explicit unknowns)

**This skill turns a settled design into a file-level plan.** It assumes the goal, the architecture (components, source of truth, interfaces), the build sequence, and the non-goals are already decided. If they aren't, run `super-brainstorming` first; a buildable-but-undesigned idea ("a clipboard-history app with one source of truth and multiple clients") belongs there. Brainstorming hands its settled design here, and you fold that recap into Goal / Context / Decisions / Approach instead of re-deriving it. Phase 3 clarification is for code-level ambiguities that exploration surfaces, not for "what's the architecture".

## Phase 2: Deep Exploration

**Minimum exploration before writing any plan:**

1. **Find all relevant files** — use Glob/Grep to locate code that touches the area
2. **Read the code** — the functions, interfaces, and types in every file you name
3. **Trace the data flow** — follow how data moves through the relevant paths
4. **Check for patterns** — how does the codebase handle similar things already?
5. **Find tests** — what existing test patterns and infrastructure exist?
6. **Fetch external references** — if the task involves a library, API, or tool, fetch the relevant docs and inline key syntax/signatures into the plan. Do NOT assume the executing session will "just look it up"
7. **Link the origin** — find the GitHub issue, PR, or conversation that motivated this work
8. **Sketch the beads breakdown (beads repos only)** — if a `.beads/` directory exists at the repo root, decompose the work into beads issues (with blocked-by dependencies) while you have full context. This is read-only here: no `bd` calls yet — you draft them into the plan (Phase 4) and file them in the post-approval handoff (Phase 6). Skip entirely for repos without `.beads/`. See `references/beads-handoff.md`.

**Use parallel subagents** for independent exploration tasks (e.g., searching for types AND finding test files AND fetching library docs simultaneously). Prefer the focused explorers over `general-purpose`: `code-explorer` for local-codebase research, `github-explorer` for GitHub repos (code, issues, PRs, releases), `web-explorer` for library/framework/API docs and general web research. Each has tighter tool allowlists and discipline baked into its system prompt.

**For agent-teams variants**, exploration happens via spawned teammates rather than the lead doing all the reads. See `references/agent-teams.md` for the spawn-prompt requirements, monitoring/synthesis loop, and the decomposition strategies for choosing teammate roles. The Phase 2 list above still applies — teammates follow it within their assigned areas.

**For TDD variants**, also identify the test framework, runner, file conventions, and existing test helpers during exploration. See `references/tdd-cycles.md` Additional Exploration Requirements.

### Exploration Red Flags — Go Back and Read More

- You're about to write "update the relevant files" without naming them
- You reference a function you haven't read
- You assume an interface shape without checking
- You don't know where tests live for this area
- You haven't checked how similar features were implemented
- You looked up docs/syntax during exploration but haven't saved the key findings anywhere yet
- There's a GitHub issue or PR motivating this work and you haven't linked it

## Phase 3: Clarify With the User

**Exploration almost always surfaces ambiguities, trade-offs, or assumptions worth verifying — assume there's something to clarify before drafting.** It's cheaper to ask now than to rewrite the plan or waste an execution cycle. If you're convinced there's nothing to ask, run the rejection test: "If the user rejects this plan, what's the most likely reason?" That reason is your question.

**What to surface:**
- **Ambiguities** — anything with multiple valid interpretations ("should this be a new component or extend the existing one?")
- **Trade-offs you discovered** — present options with pros/cons from what you found in the code ("the codebase uses pattern X for similar things, but pattern Y might be cleaner here — preference?")
- **Assumptions you're about to make** — state them explicitly and ask if they're correct ("I'm assuming we want to keep backward compatibility with the v1 API — right?")
- **Scope questions** — things that could be in or out ("should this also handle the edge case where X? or keep it simple for now?")

**How to ask:**
- Use AskUserQuestion with concrete options informed by your exploration
- One question at a time — don't dump a wall of questions
- Lead with your recommendation when you have one
- Keep going until you're confident you understand the intent

**Before moving to Phase 4**, check: "Am I about to put anything in a 'Risks' or 'Open Questions' section that I could resolve right now by asking?" If yes, ask it here. The Risks section in the plan should only contain things that are genuinely unknowable — not things you were too lazy to clarify.

Carry every confirmed answer into the Decisions table in Phase 4. It records the choices the user agreed to, not only your own analysis.

## Phase 4: Draft the Plan

### Required Sections

Every plan MUST include these sections, in this order. `check-plan` enforces the order of the required ones: Goal, Context, Decisions, Files Affected, Approach, Risks, Verification. Bracketed lines are placeholders: replace each one, or drop it along with its optional section.

- **Documentation Referenced** links every external doc, API reference, or library README consulted during exploration. It's the breadcrumb trail when an API changes or something doesn't work as expected.
- **Skills & Tools** names what the executing session should reach for. A fresh session won't have the planning context that made these choices obvious.
- **User-Confirmed Decisions** appears only when the user answered an AskUserQuestion (Phase 3 or a Phase 4.5 ESCALATE) whose answer doesn't fit the Decisions table.
- **Beads to File** appears only when the repo has a `.beads/` directory at its root. It's drafted here, filed in Phase 6, and gets its IDs written back after.

```markdown
# [Plan Title]

## Goal
[One sentence. What does "done" look like?]

## Context
- **Issue:** [Link to GitHub issue, ticket, or description of the request — omit if none]
- **Related code:** [Links to PRs, existing implementations, or examples referenced]

## Documentation Referenced
- [Library/API name](URL) — [what was learned, e.g., "streaming API accepts AsyncThrowingStream<Data>"]
- [Library/API name](URL) — [key detail]

## Skills & Tools
- **Skills:** [List skills the executing session should invoke, e.g., `test-driven-development`, `systematic-debugging`, `writing-mise-tasks`]
- **Tools:** [List MCP servers, CLI tools, or specific tooling needed, e.g., "use `xcsift` for build output", "use context7 for API docs", "use GitHub MCP for issue updates"]

## Assumptions
- [Assumption 1 — what we believe to be true and why]
- [Assumption 2 — if this is wrong, revisit step N]

## Decisions
| Decision | Options Considered | Chosen | Rationale |
|---|---|---|---|
| [e.g., State management] | [Redux, Zustand, Context] | [Zustand] | [Lightweight, fits existing patterns in `src/store/`] |

## User-Confirmed Decisions
| Question | User's Answer | Captured From |
|---|---|---|
| [Question from escalation audit or Phase 3 clarification] | [User's choice] | [Phase 3 or the escalation audit's ESCALATE finding] |

## Files Affected
- `exact/path/to/file.ts:45-67` — [what changes and why]
- `exact/path/to/other.ts` — [new file / what it contains]
- `tests/exact/path.test.ts` — [what test coverage is added]

## Approach
[2-4 paragraphs max. HOW you'll implement this, referencing actual code structures
you found during exploration. Name the functions, types, and patterns involved.]

## Key Syntax & Patterns
[Inline the actual API signatures, code patterns, or syntax discovered during
exploration that the implementation will need. Do NOT rely on "go look up the docs" —
the executing session won't have your exploration context.]

## Steps
1. [Specific action with file path]
2. [Specific action with file path]
3. [Run tests / verify]
...

## Beads to File
| Bead | Type | Priority | Blocked by | Notes |
|---|---|---|---|---|
| [short title] | [bug/feature/task/epic/chore/decision] | [0-4, 0=highest] | [another row's title, or —] | [what it covers] |

## Risks
- [Only things that are genuinely unknowable at planning time despite best-effort research]
- [If assumption X is wrong, the fallback is Y]
- [The audit outcome line, added in Phase 4.5 step 9]

## Verification
After implementation, verify before declaring done:
- Run tests: `<exact test command from exploration>`
- Run static review on the diff: `coderabbit review --agent` (or `cr review --agent`)
  - Fix Critical and Warning findings before merge.
  - If `coderabbit --version` fails or CodeRabbit isn't authenticated, skip with a note (CR is opt-in per project).
- [Any domain-specific verification — e.g., `chezmoi apply` for dotfile changes, `xcodebuild build | xcsift` for iOS, `nph` for Nim formatting]
```

**"Open Questions" belong in Phase 3, not here.** If you can ask the user about it, it's not a risk — it's an unanswered question you should have asked during clarification. Use AskUserQuestion in Phase 3 to resolve questions BEFORE drafting.

**If you can look it up, it's not a risk either.** API rate limits? Check the docs. Library compatibility? Check the README. Don't label something as a risk just because you didn't bother to verify it.

This section is ONLY for:
- True runtime unknowns that can't be answered until implementation (e.g., "actual latency under production load")
- Things you researched, couldn't find a definitive answer, AND asked the user who said "let's figure it out during implementation"

If you find yourself writing an "open question" here, STOP — either ask the user (Phase 3) or go research it (Phase 2).

### Markdown Style

Plans have to read well for a human. The Phase 4.5 gate lints them with rumdl against `~/.config/rumdl/plan.rumdl.toml`, which extends the house style in `house.rumdl.toml`. Its `--fix` pass handles spacing, list and emphasis markers, and table alignment. These rules need judgment, so write to them from the start:

- **Title and order.** Open with a `#` title. The required sections appear in template order.
- **Title Case headings, code in backticks.** Wrap every identifier, path, and tool name in a heading in backticks: ``### Wiring `check_plan` into `prek` ``. rumdl never recases code spans; outside one, it would rewrite `check_plan` as `Check_plan`.
- **A real language on every code fence**: `nim`, `bash`, `toml`, and so on. Use `text` only for output that really is plain text.
- **No empty sections.** Every heading from `##` down needs body text, or a subheading that has body text. Omit an optional section instead of leaving it empty.
- **Bold sparingly.** At most three bold phrases per paragraph. Save bold for what a skimming reader must not miss.
- **Labels are list items, not bold lines.** A bold phrase alone on its line (`**Verify RED**`) fails the gate. Put the label at the start of a numbered or bulleted item instead: `2. **Verify RED.** Run ...`.

### Code Snippets Are Required

Steps that involve code changes MUST include a concrete code snippet showing the change. Snippets serve as **proof of understanding** — they let the user verify you actually know what functions exist, what types look like, and what API calls to make.

**Snippets must be real code, not wishful thinking:**
- Use actual function names, types, and signatures from exploration
- Show the key logic, not the entire file
- Never include placeholder comments like `// TODO: figure this out` or `# Handle the edge cases here`
- Never write "same as step N" or "similar to the above" — repeat the code in full. Steps may be executed out of order, and agent-teams teammates read their section in isolation

If you can't write the snippet, you haven't explored enough. Go back to Phase 2.

**Good snippet (shows real understanding):**
```typescript
// In src/components/Form.tsx — add to handleSubmit at line 34
const validated = userSchema.safeParse(formData);
if (!validated.success) {
  setErrors(validated.error.flatten().fieldErrors);
  return;
}
await createUser(validated.data);
```

If a step involves creating or modifying code and has no snippet, the plan is incomplete.

### Variant-Specific Steps Format

The Steps section above (a flat numbered list) is the default for **Single** variants. For TDD variants, replace it with red-green-refactor cycles per `references/tdd-cycles.md` Steps Section Format. For Agent Teams variants, the plan is a directory with `index.md` + numbered section files instead of a single flat list — see `references/agent-teams.md` Multi-File Plan Output.

### Specificity Requirements

| Vague (reject) | Specific (accept) |
|---|---|
| "Update the handler" | "Add validation to `handleSubmit` in `src/components/Form.tsx:34`" |
| "Add tests" | "Add test case to `tests/form.test.ts` using the existing `renderForm` helper" |
| "Modify the type" | "Extend `UserProfile` in `src/types.ts:12` with optional `displayName: string`" |

**Rule:** If a step doesn't include a file path, it's not specific enough.

### Alternatives (When Applicable)

If there are genuinely different approaches (not just one obvious path), present 2-3 options as `###` subsections under `## Approach`, with the recommendation in its opening paragraph:

```markdown
## Approach

[One paragraph: the recommended option and the concrete reason it wins.]

### Option A: [Name]

- Pros: ...
- Cons: ...

### Option B: [Name]

- Pros: ...
- Cons: ...
```

Don't force alternatives when there's clearly one right answer.

## Phase 4.5: Independent Plan Audits (default-on)

After writing the draft to the plan file, run **two parallel audits** before calling ExitPlanMode. They review different things and shouldn't block each other:

1. **Codex audit** (`codex:codex-rescue`) — fresh-eyes implementation review. Catches wrong code references, missing context, broken snippets, false assumptions about the code. Variant-specific prompt.
2. **Opus escalation audit** (`general-purpose` agent with `model: "opus"`) — adversarial review focused on user-attention items. Catches accepted regressions, scope reductions, breaking changes, and decisions the planner made on the user's behalf without surfacing them. Variant-agnostic prompt.

The two audits answer different questions. Codex asks "is this plan technically correct?" Escalation asks "did the planner sneak past anything the user must approve?" The escalation audit exists because the technical-correctness review tends to defer to the planner's framing of tradeoffs ("regression is fine because X") instead of escalating to the user.

**Bypass:** If the user said "skip audit" / "skip audits" / "skip codex audit" / similar in this plan mode session, omit BOTH passes, record `Phase 4.5 audits: skipped per user request.` as the outcome line (step 9), and go straight to the gate (step 10). Default behavior is to run both.

**Procedure:**

1. Compose the prompts per `references/audit-prompts.md` — that file owns the (variant × TDD) → file composition table and the TDD-additions renumbering rules.
2. **Spawn both audits in parallel** — single message, two `Agent` tool calls. Phrase the Codex prompt without `--write` keywords (the rescue agent strips routing flags; read-only is the codex default). The escalation audit uses `subagent_type: "general-purpose"` with `model: "opus"` — Opus tier matters here for spotting motivated reasoning, don't downgrade.
3. Read both sets of findings.
4. **Codex CRITICAL / WARNING findings → revise the plan.** Edit the plan file directly (the only file editable in plan mode). Per `codex-result-handling`, do NOT auto-apply Codex's suggested fixes to source code — the audit reviews the plan, not the source.
5. **Escalation ESCALATE findings → use AskUserQuestion for each one** before ExitPlanMode. Do NOT silently fold them into the Risks section, do NOT rationalize them away, and do NOT batch them into a wall of questions — one AskUserQuestion per finding (or grouped tightly when they share an option set). After the user answers, capture the decision in the plan's Decisions table or, when answers don't fit existing decisions, in a `## User-Confirmed Decisions` section so a fresh session can see the user's sign-off.
6. **Escalation VERIFY findings → mention briefly in your ExitPlanMode summary** so the user has visibility, but they're not blocking. Don't pre-emptively edit the plan based on them.
7. **After revisions, re-run BOTH audits ONCE more** (cap at 2 total passes per audit). If the second pass still surfaces CRITICAL or unresolved ESCALATE findings, escalate to the user via AskUserQuestion before ExitPlanMode rather than starting a third pass.
8. **Partial-failure handling:** If only one audit agent is unavailable (auth error, runtime failure, agent not registered), proceed with the one that ran and record the gap in the outcome line. If both fail, surface to the user and offer to skip with that recorded, rather than retrying indefinitely.
9. **Record the outcome.** Add exactly one line to Risks, whatever happened, starting `Phase 4.5 audits:`. Fold any remaining Info / OK findings into it as non-blocking notes:
   - `Phase 4.5 audits: Codex clean (pass 1); escalation clean (pass 1).`
   - `Phase 4.5 audits: Codex pass 2, Info (non-blocking): the retry cap is untested; escalation clean (pass 1).`
   - `Phase 4.5 audits: Codex unavailable (auth error); escalation clean (pass 1).`
   - `Phase 4.5 audits: skipped per user request.`
10. **Run the gate**, then proceed to Phase 5 once it passes:

    ```bash
    check-plan --fix <plan-file-or-directory>
    ```

    `check-plan` is a Nim binary on PATH, built by chezmoi from `scripts/claude/check_plan.nim`. It applies rumdl's safe fixes, lints the plan against the Markdown Style rules and required section order, and fails unless the plan file (or `index.md`) carries a `Phase 4.5 audits:` line.

    - **Exit 0**: pass.
    - **Exit 1**: fix each remaining finding in the plan file, then rerun. Heading case (MD063) and fence language (MD040) findings are always left for you: add backticks or recase the heading, and name the fence's real language. **Never run `rumdl fmt` or `rumdl check --fix` yourself**, even though rumdl's summary suggests it. Those fixes rewrite identifiers in headings and label every unknown fence `text`. Style fixes need no re-audit; adding a missing section does.
    - **Exit 2**: a setup problem, such as rumdl missing from PATH, a missing config (`chezmoi apply`), a bad path, or a plan directory with no `index.md`. Fix a missing `index.md` yourself; tell the user about the rest instead of skipping the gate.

## Phase 5: Compaction Question & Exit

1. **Ask the required compaction question.** Before `ExitPlanMode`, always run one `AskUserQuestion` — even on small plans, the user decides. The point: implementation should start on a clean slate if this planning session burned a lot of context, and the post-approval handoff (Phase 6) is where any management work happens *before* the user compacts. Compute a recommendation and flag it on the matching option:

   | Recommendation | Signals | Option to offer |
   |---|---|---|
   | **Continue** | Single variant, few files read, ≤1 subagent, short plan | "Continue in this session" |
   | **/compact first** *(recommended)* | Moderate exploration — many files read, a few subagents, plan spans several areas, or the session already feels deep | "/compact, then implement" |
   | **Fresh session** *(necessary)* | Agent-teams variant, many subagents, very large plan, or the session is near its context budget — `/compact` won't reclaim enough working room | "Start a fresh session" |

   Phrase it as: *"Compact before I start implementing?"* with those three options, the computed recommendation appended to the matching label (e.g. `/compact, then implement (recommended)`). Don't skip the question, and don't pre-decide by acting without asking.
2. Call `ExitPlanMode` for user approval.

## Phase 6: Post-Approval Handoff

**This phase runs AFTER `ExitPlanMode` is approved — you're back in normal mode, same session. Do NOT dive into implementation yet.** This is the management window: file beads, then honor the compaction choice. Barreling straight into code edits here is the specific behavior this phase exists to prevent.

> **This is not the `handoff` skill.** Despite the shared name, this phase writes no `.handoff/` doc — the **plan file is the handoff** here, and it already passes the self-containment test below. Reach for the `handoff` skill only once implementation is *underway* and there's execution state (progress against the plan, what broke, what you discovered) that the plan can't hold. Writing a handoff doc for an approved-but-unstarted plan just duplicates it.

1. **File beads (beads repos only).** If a `.beads/` directory exists at the repo root and the plan has a `## Beads to File` section, create the issues now, wire up dependencies, capture IDs, and write them back into the plan's table. Auto-filed, then reported — no extra confirmation. Follow `references/beads-handoff.md` for the exact `bd` procedure. No `.beads/` → skip silently.
2. **Honor the compaction choice** from Phase 5:
   - **Continue** → proceed to implement.
   - **/compact first** or **Fresh session** → STOP with a clean handoff message and let the user drive the compaction. Name what was filed and where the plan lives, e.g.: *"Handoff done. Filed bd-a1b2, bd-c3d4, bd-e5f6 (bucket → wiring → tests). Plan at `plans/rate-limiter.md` is self-contained — `/compact` (or open a fresh session), then say go and I'll implement."* Don't touch code until they come back.

## The Self-Containment Test

Before calling ExitPlanMode, ask yourself:

> If a fresh session reads ONLY this plan file with zero prior context, can it start implementing immediately without looking anything up?

If the answer is no, the plan is missing context. Either way, run the checklist in `references/common-mistakes.md` now: the common self-containment gaps, plus the exploration, drafting, audit, and handoff mistakes the gate can't catch.
