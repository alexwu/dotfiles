# Claude Sonnet 5

Source: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5>
Fetched: 2026-09-29
Builds on: Sonnet 4.6 prompts, which work out of the box. [`sonnet-5-5.md`](sonnet-5-5.md) builds on this file.

Sonnet 5 is strong at coding and agentic work. Adaptive thinking is **on by default** (a change from Sonnet 4.6); manual `budget_tokens` returns a 400. Effort defaults to `high`; use `xhigh` for the hardest coding. Rough migration map: Sonnet 5 `medium` ≈ Sonnet 4.6 `high`, Sonnet 5 `high` ≈ Sonnet 4.6 `max`. Match by observed thinking length, not effort name. Non-default `temperature`, `top_p`, or `top_k` returns a 400. Mid-conversation system messages are **not** available on Sonnet 5.

## Symptoms and fixes

| You see | Fix |
|---|---|
| Length swings with task complexity | Add a conciseness line. Positive examples of the right concision beat "don't" rules. |
| Shallow reasoning at `low` | Raise effort first. If `low` is required, add the multistep-reasoning line. |
| Thinks more than you want | Add the thinking-trigger line and measure. |
| `max_tokens` cut-offs on workloads that ran without thinking on 4.6 | `max_tokens` bounds thinking plus text. Revisit it, or try thinking on at lower effort. |
| Fewer tool calls with thinking disabled | Add an explicit tool-use nudge; raise effort; say when and why to use each tool. |
| Forced status-message scaffolding | Remove it; describe the update shape you want if the defaults are off. |
| Instruction applied to one item only | It reads literally, especially at low effort. State the scope. |
| Voice shifted after upgrade | Re-evaluate style prompts. Use system-prompt tone instructions in place of `temperature`. |
| Same visual style on every design brief | Give a concrete alternative spec (see the AEFRM example in [`opus-4-8.md`](opus-4-8.md)) or have it propose four directions first. That's the recommended source of variety now that `temperature` is gone. |
| Review recall drops | "Only report high-severity" is followed literally. Use the coverage prompt from [`opus-4-8.md`](opus-4-8.md) (identical wording) and filter downstream. |
| Interactive coding costs more tokens | Specify task, intent, and constraints in the first turn; use `xhigh`/`high` and an auto mode. |

Computer use: 1080p screenshots balance cost and accuracy; 720p or 1366×768 for cost-sensitive work.

## Recommended snippets (verbatim)

```text
Provide concise, focused responses. Skip non-essential context, and keep examples minimal.
```

```text
This task involves multistep reasoning. Think carefully through the problem before responding.
```

```text
Thinking adds latency and should only be used when it will meaningfully improve answer quality, typically for problems that require multistep reasoning. When in doubt, respond directly.
```

```text
Use a warm, collaborative tone. Acknowledge the user's framing before answering.
```

```text
Before building, propose 4 distinct visual directions tailored to this brief (each as: bg hex / accent hex / typeface, plus a one-line rationale). Ask the user to pick one, then implement only that direction.
```

```text
<frontend_aesthetics>
NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white or dark backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character. Use unique fonts, cohesive colors and themes, and animations for effects and micro-interactions.
</frontend_aesthetics>
```
