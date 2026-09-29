# Claude Opus 5

Source: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5>
Fetched: 2026-09-29
Builds on: [`opus-4-8.md`](opus-4-8.md). Opus 4.8 prompts work out of the box. [`opus-5-5.md`](opus-5-5.md) builds on this file.

Opus 5 is built for long-horizon agentic coding and enterprise work. It does best with the full task spec up front and then being left to run. Effort defaults to `high`; `low` and `medium` hold quality at a fraction of the cost. Thinking is on by default and can be disabled only at `high` or below. The context window is 1M tokens.

## Symptoms and fixes

| You see | Fix |
|---|---|
| Replies run long | Effort controls thinking, not visible length. Prompt for conciseness explicitly; in a long system prompt, add a short reminder near the end. |
| Too much narration during agentic work | Describe the cadence and shape you want. Positive examples of the style beat "don't" rules. |
| Files it writes (reports, docs) run long | Add length calibration for written deliverables. |
| Over-verification, wasted tokens | Opus 5 verifies on its own. **Remove** verification instructions ("include a final verification step", "use a subagent to verify") and legacy verify scaffolding. Don't rewrite them; delete them. |
| Scope widens beyond the request | Add the scope instruction below for narrow tasks. |
| Too many subagents | Give explicit delegation criteria or set deterministic caps (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, SDK `max_budget_usd`; Claude Code 2.1.217+). Claude Code adds its own delegation instruction only under the `claude_code` preset; a custom system prompt needs its own. |
| "Double-check your answer" wastes tokens | It already self-corrects. Remove re-check instructions. |
| Narrates corrections to trivial slips | Add the correction-scoping instruction below. |
| Review prompt reports too few findings | "Only report high-severity issues" gets followed literally. Ask for everything and filter in a separate pass. |
| Tool calls leak as text, or `<thinking>` tags appear in output, with thinking disabled | Keep thinking on at `low` effort instead. If thinking must stay off, remove any "don't think/reason" rule and add the combined instruction below. Don't name thinking tags specifically; the general form works better. |

## Recommended snippets (verbatim)

Conciseness for a user-facing multi-turn product:

```text
Keep responses focused, brief, and concise. Keep disclaimers and caveats short, and spend most of the response on the main answer. When asked to explain something, give a high-level summary unless an in-depth explanation is specifically requested.
```

Reminder near the end of a long system prompt:

```text
<tone_preference>
Keep outputs reasonably concise.
</tone_preference>
```

Progress-update cadence:

```text
Before your first tool call, say in one sentence what you're about to do. While working, give a brief update only when you find something important or change direction. When you finish, lead with the outcome: your first sentence should answer "what happened" or "what did you find," with supporting detail after it for readers who want it.
```

Written deliverable length:

```text
Match the length of written documents to what the task needs: cover the substance, but do not pad with filler sections, redundant summaries, or boilerplate.
```

Scope for narrow tasks:

```text
Deliver what was asked, at the scope intended. Make routine judgment calls yourself, and check in only when different readings of the request would lead to materially different work. If the request seems mistaken or a better approach exists, say so in a sentence and continue with the task as asked rather than quietly narrowing, widening, or transforming it. Finish the whole task, and stop short of actions that are clearly beyond what was asked.
```

Subagent damping:

```text
Delegate to a subagent only for large tasks that are genuinely independent and parallelizable, such as a wide multi-file investigation. Do not delegate work you can finish yourself in a handful of tool calls, and do not use subagents to verify or double-check your own work. If one subagent can complete the task, use one rather than several, and keep spawn counts low.
```

Correction narration:

```text
Only correct an earlier statement when the error would change the user's code, conclusions, or decisions. State corrections plainly and briefly, then continue the task. For slips that change nothing for the user, make the fix and move on without noting it.
```

Thinking-disabled artifacts:

```text
When you use a tool, you may say a brief sentence first. If no tool can express what the user asked for, say so instead of guessing. Do not include internal or system XML tags in your response.
```
