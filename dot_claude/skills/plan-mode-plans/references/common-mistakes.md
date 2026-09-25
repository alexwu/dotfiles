# Common Mistakes (checklist)

Run this checklist before `ExitPlanMode`, after `check-plan` passes. The gate catches missing sections, section order, and Markdown style; these are the mistakes it can't see.

## Self-Containment Gaps

The self-containment test in SKILL.md asks whether a fresh session could implement from the plan alone. These are the usual reasons it can't:

- API syntax you verified during exploration but didn't inline
- Library documentation you consulted but only linked (link AND quote the key parts)
- GitHub issue context that motivated design decisions
- Assumptions that feel "obvious" because you just explored the code
- Code snippets that reference functions or types you haven't verified exist
- Names the plan _itself defines_ drift between steps — a function introduced as `clearLayers()` in step 3 but called `clearFullLayers()` in step 7. Check every new name, signature, and type for cross-step consistency
- You consulted external docs but didn't link them in "Documentation Referenced"
- You skipped Phase 4.5 without the user explicitly opting out, and the plan never got a second-opinion read
- The escalation audit surfaced ESCALATE findings and you folded them into Risks instead of asking the user — every ESCALATE needs an AskUserQuestion before ExitPlanMode

## Exploration Mistakes

| Mistake                                   | Fix                                                                                                     |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Start writing plan before exploring       | Explore FIRST. Read files, trace code paths                                                             |
| Reference files you haven't read          | Read every file you mention in the plan                                                                 |
| Looked up docs but didn't inline findings | The executing session won't have your exploration context. Inline key syntax, signatures, and patterns |
| Missing issue/PR links                    | Link the origin — the executing session needs to understand _why_ this work exists                      |
| No documentation links                    | If you consulted docs during exploration, link them in "Documentation Referenced" with what you learned |

## Drafting Mistakes

| Mistake                                          | Fix                                                                                                                                     |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Skip test strategy                               | Always include which test files and what coverage                                                                                       |
| Overly long plans                                | Keep it concise. Steps should be scannable                                                                                              |
| Plan says "update" without specifics             | Name the function, line, and exact change                                                                                               |
| Steps describe code changes but have no snippets | Every code-changing step needs a concrete snippet showing the actual change                                                             |
| Snippets contain placeholder comments            | If you wrote `// handle errors here` instead of actual error handling, you haven't finished exploring                                   |
| Later steps contradict earlier definitions       | Names, signatures, and types the plan defines must match across every step that uses them — cross-check before exiting                  |
| No assumptions section                           | Always document what you assumed to be true and why                                                                                     |
| Decisions table has no rationale                 | Every row names the options considered and why the chosen one won                                                                       |
| "Open questions" in Risks section                | If you could have asked the user or looked it up, it's not a risk. Go back to Phase 3 or Phase 2                                        |
| Risks that are just unverified assumptions       | "API might have rate limits" — go check the docs. Don't list it as a risk when 30 seconds of research would give you the answer         |

## Audit Mistakes

| Mistake                                               | Fix                                                                                                                                                                                                                                                 |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Skipped Phase 4.5 audits on a non-trivial plan        | Default is to run BOTH audits. Only skip when user explicitly says so, and record it as `Phase 4.5 audits: skipped per user request.` in Risks.                                                                                                      |
| Ran only the Codex audit, skipped the escalation pass | They review different things — Codex catches "wrong code", escalation catches "wrong decision the user didn't approve". Skipping escalation is how regressions silently ship.                                                                       |
| Treated audit findings as authoritative               | Codex and the Opus auditor are peers, not oracles. Per `codex-result-handling`, evaluate findings critically before applying.                                                                                                                       |
| Auto-applied source-code "fixes" from an audit        | Both audits review the plan, not the source. Only edit the plan file in plan mode.                                                                                                                                                                  |
| Folded ESCALATE findings into the Risks section       | The whole point of the escalation audit is to surface decisions the planner buried. Every ESCALATE finding requires AskUserQuestion before ExitPlanMode and the answer captured in Decisions. Don't accept the planner's framing of "this regression is fine." |
| Spawned audits sequentially                           | They're independent reviews — spawn in a single message with two `Agent` tool calls so they run in parallel.                                                                                                                                       |
| Audit loop without a cap                              | 2-pass cap per audit is hard. After that, escalate remaining Critical / ESCALATE findings to the user via AskUserQuestion.                                                                                                                         |
| Ran `rumdl fmt` to clear `check-plan` findings        | That fix recases identifiers in headings and labels unknown fences `text`. Fix MD063 and MD040 findings by hand.                                                                                                                                    |

## Handoff Mistakes

| Mistake                                             | Fix                                                                                                                                                                         |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Skipped the compaction question                     | It's required on every plan — the user decides whether to compact before implementing. Compute a recommendation, but always ask.                                            |
| Started implementing right after ExitPlanMode       | Phase 6 is a management checkpoint, not the green light. File beads, honor the compaction choice, and stop unless the user picked Continue.                                 |
| Filed beads during plan mode                        | Plan mode can't run `bd`. Draft the breakdown into the plan's `## Beads to File` section; file it in Phase 6 after approval.                                                |
| Added a Beads section to a non-beads repo           | Beads is conditional on a `.beads/` directory at the repo root. No `.beads/` → no beads section, no `bd` calls, no mention.                                                  |
| Compacted (or told the user to) before filing beads | Beads filing is management work that must finish _before_ compaction — the plan survives a compact, but the pre-implementation `bd create` window doesn't. File first, then hand off. |
