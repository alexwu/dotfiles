# Agent Teams (variant reference)

Loaded when the chosen variant uses agent teams (3+ independent areas, parallel exploration, multi-file plan output).

**Core principle:** The lead orchestrates, teammates explore and draft in parallel. Each teammate owns one area of the codebase and one section of the plan. Plans are split across files in a directory.

**Prerequisite:** Agent teams must be enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` in settings or environment.

## Phase 1 Addition: Decompose

Beyond the universal Phase 1 in SKILL.md, also choose a decomposition strategy and define teammate roles.

### Decomposition Strategies

| Strategy | When to Use | Example Roles |
|---|---|---|
| **By layer** | Full-stack feature spanning multiple layers | data-layer, api-routes, ui-components, tests |
| **By domain** | Feature touching multiple bounded contexts | auth-domain, billing-domain, notification-domain |
| **By file area** | Large refactor touching many directories | src/models/, src/views/, src/services/ |
| **By concern** | Cross-cutting changes | core-logic, error-handling, migration, documentation |
| **By dependency chain** | Ordered work with clear prerequisites | schema-first → API → client → UI |

**Aim for 3-5 teammates.** Each teammate should have a clear, independent exploration scope. If you can't define 3 independent areas, fall back to single-session (don't load this reference; use `single-session.md` only).

For each teammate, define:
- **Name/label** — descriptive, e.g. "data-layer-explorer"
- **Exploration area** — which files, directories, and concerns they investigate
- **Section they'll draft** — the plan section file they'll own

## Phase 2 Replacement: Agent Team Exploration

This replaces the single-session Phase 2 in SKILL.md.

### Lead Initial Sweep

Before spawning teammates, the lead does a brief structural scan (Glob/Grep only, not deep reads):
- Project structure and entry points
- Validate that the decomposition strategy makes sense
- Identify any shared code that multiple teammates will need to know about

This should be quick — just enough to write good spawn prompts. Deep exploration is the teammates' job.

### Create Team and Spawn Teammates

1. Create the team with `TeamCreate` (creates shared task list at `~/.claude/tasks/{team-name}/`)
2. Spawn each teammate using the `Agent` tool with `team_name` and `name` parameters
3. Create tasks for each teammate via `TaskCreate`, then assign with `TaskUpdate` (set `owner` to teammate name)

**Every teammate spawn prompt MUST include:**

1. **Overall goal** — what the full task is (the teammate needs big-picture context)
2. **Their specific area** — exactly which files, directories, and concerns to explore
3. **Plan directory path** — where to write their section file
4. **Section filename** — their numbered section file (e.g., `02-api-routes.md`)
5. **Exploration standards** — the universal exploration list from SKILL.md Phase 2
6. **Section file format** — the exact template (see Section File Format below)
7. **Shared context** — any findings from the lead's initial sweep that affect their area

**Example spawn prompt structure:**
```
You are exploring the data layer for a task to [overall goal].

Your area: [specific directories, files, concerns]

Explore following these standards:
- Find all relevant files using Glob/Grep
- Read the actual code — functions, interfaces, types
- Trace how data flows through [specific paths]
- Check how similar things are handled in the codebase
- Find existing tests and test patterns for this area
- Fetch docs for [relevant libraries] if needed

Shared context from lead:
- [Key findings from initial sweep]

Write your findings as a plan section to: plans/{plan-name}/02-data-layer.md
Use this format:
[section file template]
```

### Monitoring and Synthesis

- Monitor teammate progress via `TaskList` (checks shared task list at `~/.claude/tasks/{team-name}/`)
- Read completed section files as they come in
- After all teammates complete, synthesize:
  - Check for overlapping Files Affected between sections
  - Identify contradictory Decisions or Assumptions
  - Resolve conflicts (choose one recommendation with rationale, or flag for Phase 3)
  - Merge Files Affected into a unified aggregate for the index

**Conflict resolution rules:**
- Two sections modify the same file → reconcile changes (order, merge, or re-split ownership)
- Contradictory assumptions → escalate to user in Phase 3
- One section's approach invalidates another → lead rewrites affected steps

### Teammate Communication

Teammates can message each other directly via `SendMessage` (type: `"message"`, specifying `recipient` by teammate name). If a teammate discovers something that affects another teammate's area, they should message the relevant teammate and note the cross-cutting concern in their section's Dependencies.

Use `SendMessage` with type `"broadcast"` sparingly — only for critical issues that affect all teammates (e.g., "the project uses a completely different framework than expected, everyone stop and reassess").

## Phase 4 Replacement: Multi-File Plan Output

This replaces the single-session "Required Sections" template in SKILL.md.

### Plan Directory Structure

Plans always use a directory with an index and numbered section files:

```
plans/{plan-name}/
  index.md              # Master index (lead-authored)
  01-{section-slug}.md  # Teammate-drafted sections
  02-{section-slug}.md
  03-{section-slug}.md
  ...
```

The plan-name directory replaces the single `{plan-name}.md` file. Numbered prefixes enforce reading and implementation order. Section slugs are descriptive (e.g., `01-data-layer.md`, `02-api-routes.md`).

### index.md Format

The master index is authored by the lead and contains:

```markdown
## Goal
[One sentence. What does "done" look like?]

## Context
- **Issue:** [Link to GitHub issue, ticket, or description of the request — omit if none]
- **Related code:** [Links to PRs, existing implementations, or examples referenced]

## Documentation Referenced
- [Library/API name](URL) — [what was learned]
[Merged from all teammate findings]

## Skills & Tools
- **Skills:** [List skills the executing session should invoke]
- **Tools:** [List MCP servers, CLI tools, or specific tooling needed]

## Assumptions
[Merged from all sections, conflicts resolved]
- [Assumption 1 — what we believe to be true and why]

## Decisions
| Decision | Options Considered | Chosen | Rationale |
|---|---|---|---|
[Merged decision table, conflicts resolved with rationale]

## Section Map
| # | Section | File | Owner | Status |
|---|---|---|---|---|
| 1 | Data Layer | 01-data-layer.md | data-layer-explorer | Complete |
| 2 | API Routes | 02-api-routes.md | api-explorer | Complete |
| 3 | UI Components | 03-ui-components.md | frontend-explorer | Complete |

## Files Affected
[Merged aggregate from all section files — every file mentioned across all sections]
- `exact/path/to/file.ts:45-67` — [what changes and why]

## Approach
[2-4 paragraphs — how all sections fit together, implementation order, integration points]

## Synthesis
[Cross-cutting decisions and conflict resolutions. What the lead decided when teammates disagreed or areas overlapped.]

## Risks
[Only genuinely unknowable things — not unasked questions or unresearched assumptions]
- [If assumption X is wrong, the fallback is Y]

## Verification
After implementation, verify before declaring done:
- Run tests: `<exact test command from exploration>`
- Run static review on the diff: `coderabbit review --agent` (or `cr review --agent`)
  - Fix Critical and Warning findings before merge.
  - If `coderabbit --version` fails or CodeRabbit isn't authenticated, skip with a note (CR is opt-in per project).
- [Any domain-specific verification — e.g., `chezmoi apply` for dotfile changes, `xcodebuild build | xcsift` for iOS, `nph` for Nim formatting]
```

### Section File Format

Each teammate writes their section file following this template:

```markdown
## {Section Name}

### Scope
[What this section covers — specific directories, concerns, boundaries]

### Files Affected
- `exact/path/to/file.ts:45-67` — [what changes and why]
- `exact/path/to/new-file.ts` — [new file, what it contains]

### Key Syntax & Patterns
[API signatures, code patterns, or syntax relevant to this section's implementation. Inline the actual syntax — do NOT rely on "go look up the docs".]

### Dependencies
- **Depends on:** [other section names — must be implemented first]
- **Blocks:** [other section names — cannot start until this is done]

### Steps
1. [Specific action with file path and code snippet]
2. [Specific action with file path and code snippet]
3. [Run tests / verify]
...
```

### Lead Review Gates

Before accepting a teammate's section file, the lead checks:

| Check | Fail Condition | Action |
|---|---|---|
| Specificity | Steps without file paths | Create revision task via `TaskCreate` |
| Snippets | Placeholder comments instead of real code | Create revision task via `TaskCreate` |
| Self-containment | References files or functions not explored | Create revision task via `TaskCreate` |
| Unresolved questions | "Open questions" that should have been explored | Send back to explore |
| Cross-section conflicts | Contradicts another section's approach | Lead resolves or escalates |
| Codex audit clean or escalated (Phase 4.5) | Critical findings remain after 2 passes | Escalate to user via AskUserQuestion before shutdown |

If a section fails review, the lead creates a follow-up task via `TaskCreate`: `Revise: {section-name} — {specific issue}`, and messages the teammate via `SendMessage` with the feedback.

## Phase 4.5 Note

The base SKILL.md owns Phase 4.5. For multi-file plans, compose the audit prompt from `references/audit-prompt-multifile.md`. The lead invokes the audit ONCE on the composed plan (`index.md` + all section files) before shutting down teammates. Per-section audit was rejected as too costly. The audit happens BEFORE teammate shutdown — the lead handles any audit-driven revisions directly.

## Phase 5 Addition: Cleanup

Beyond the universal Phase 5 in SKILL.md:

1. Verify all section files are written to the plan directory
2. Verify `index.md` is written with complete merged view
3. **Cross-file self-containment test:** A fresh session reading `index.md` first, then section files in numbered order, can implement everything without looking anything up
4. Shut down all teammates via `SendMessage` (type: `"shutdown_request"`)
5. Clean up the team via `TeamDelete` after all teammates confirm shutdown
6. Call ExitPlanMode for user approval

## Self-Containment Test (multi-file additions)

In addition to the universal self-containment test in SKILL.md:

- A section references another section's work without explaining what it needs
- You skipped Phase 4.5 without the user explicitly opting out, and the composed plan never got a second-opinion read
- The index.md Verification section is missing or vague — the executing session needs a concrete `coderabbit review --agent` checkpoint

## Common Mistakes (multi-file specific)

| Mistake | Fix |
|---|---|
| Spawn prompt missing overall context | Teammate explores blindly. Always include the full task goal. |
| Too many teammates (>5) | Coordination overhead exceeds benefit. 3-5 is the sweet spot. |
| Lead does all exploration instead of delegating | Defeats the purpose. Lead does a brief sweep, teammates do the deep work. |
| No synthesis step | Section files contradict each other. Always synthesize before Phase 3. |
| Sections have overlapping Files Affected without reconciliation | Lead must reconcile — order changes, merge, or re-split ownership. |
| Skipping lead review of section files | Quality issues compound. Review every section before writing index. |
| Forgot to shut down teammates and TeamDelete | Always clean up the team before ExitPlanMode. |
| Ran per-section audits instead of one composed audit | One audit over `index.md` + all sections. Per-section is too costly and misses cross-section issues. |
| Ran audit AFTER `TeamDelete` | Lead may need section-file edits based on findings. Audit BEFORE shutdown. |
| Missing Verification section in index.md | Required. Without it, the executing session has no checkpoint after implementation. |
