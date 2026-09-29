# Claude Opus 4.8

Source: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8>
Fetched: 2026-09-29
Builds on: Opus 4.7 prompts, which work out of the box. [`opus-5.md`](opus-5.md) builds on this file.

Opus 4.8 is strong on long-horizon agentic work, knowledge work, vision, and memory tasks. Thinking is **off** unless you set `thinking: {type: "adaptive"}`. Effort matters more on this model than on any earlier Opus: start at `xhigh` for coding and agentic work and use at least `high` for intelligence-sensitive work.

## Symptoms and fixes

| You see | Fix |
|---|---|
| Length swings with task complexity | It calibrates length to the task. Add a conciseness line if your product needs a fixed register. Positive examples beat "don't" rules. |
| Shallow reasoning at `low` | Raise effort to `high`/`xhigh` first. If `low` is required, add the multistep-reasoning line below. |
| Thinks more often than you want (large system prompts) | Add the thinking-trigger line below and measure. |
| Too few tool calls | It favors reasoning over tools. Raise effort, and say when and why to use each tool. |
| Forced status-message scaffolding | Remove "after every 3 tool calls, summarize"; its updates are better unprompted. Describe the shape you want if they're off. |
| Instruction applied to one item only | It reads literally and doesn't generalize an instruction across items. State the scope ("apply this to every section, not just the first one"). |
| Voice too blunt | Its default is direct and opinionated. Add the warm-tone line if your product needs warmth. |
| Too few subagents | It spawns fewer by default. Say when subagents are wanted. |
| Every design comes out cream, serif, and terracotta | The house style (~`#F4F1EA` backgrounds, Georgia/Fraunces/Playfair, italic word accents, terracotta/amber) is persistent. Generic "don't use cream" shifts it to another fixed palette. Give a concrete alternative spec or have it propose options first. |
| Interactive coding sessions cost more | It reasons more after each user turn. Put the task, intent, and constraints in the first turn and cut required interactions. |
| Review recall drops after a model swap | Harness effect: "only report high-severity" is obeyed literally. Use the coverage prompt below and filter downstream. For a single pass, state the bar concretely rather than "important". |

## Recommended snippets (verbatim)

```text
Provide concise, focused responses. Skip non-essential context, and keep examples minimal.
```

```text
This task involves multistep reasoning. Think carefully through the problem before responding.
```

```text
Thinking adds latency and should only be used when it will meaningfully improve answer quality — typically for problems that require multistep reasoning. When in doubt, respond directly.
```

```text
Use a warm, collaborative tone. Acknowledge the user's framing before answering.
```

Subagent guidance (a toy coding example):

```text
Do not spawn a subagent for work you can complete directly in a single response (e.g. refactoring a function you can already see).

Spawn multiple subagents in the same turn when fanning out across items or reading multiple files.
```

Propose design directions before building:

```text
Before building, propose 4 distinct visual directions tailored to this brief (each as: bg hex / accent hex / typeface — one-line rationale). Ask the user to pick one, then implement only that direction.
```

Minimal frontend aesthetics directive:

```text
<frontend_aesthetics>
NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white or dark backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character. Use unique fonts, cohesive colors and themes, and animations for effects and micro-interactions.
</frontend_aesthetics>
```

Code-review coverage:

```text
Report every issue you find, including ones you are uncertain about or consider low-severity. Do not filter for importance or confidence at this stage - a separate verification step will do that. Your goal here is coverage: it is better to surface a finding that later gets filtered out than to silently drop a real bug. For each finding, include your confidence level and an estimated severity so a downstream filter can rank them.
```

Concrete single-pass bar (inline in the guide): "report any bugs that could cause incorrect behavior, a test failure, or a misleading result; only omit nits like pure style or naming preferences."

Concrete-alternative design spec, the guide's model of "specify a concrete alternative" (the Sonnet 5 guide reuses it):

```text
Design a desktop landing page for a supplement brand called AEFRM.

The visual direction should come from a cold monochrome atmosphere using pale silver-gray tones that gradually deepen into blue-gray and near-black, similar to a misted metallic surface.

The page should feel sharp and controlled, with a strong sense of structure and restraint.

Use this tonal system across the full page instead of introducing bright accent colors.

Use the uploaded image on the hero design in black and white.

The layout should be built with clear horizontal sections and a centered max-width container. Use 4px corner radius consistently across cards, buttons, inputs, and media frames. Margins should feel generous, with enough empty space around each section so the page breathes.

Typography should use a square, angular sans-serif with wider letter spacing than usual, especially in headings and navigation, so the text feels more engineered and less compressed. Headline text can be large and uppercase, while supporting copy remains short and sparse. The sub texts should be written with Alumni Sans SC in 4-6px like tiny little texts on corners bottom centre like that.

For the structure, start with a hero section containing a strong product statement, one short supporting paragraph, and a clean product placeholder or packshot frame. Below that, add a benefit grid with three or four blocks, then a formulation or ingredients section, and finally a cta.

Buttons should be flat and precise, with subtle hover changes using transition: all 160ms ease out where brightness and border contrast shift slightly rather than using dramatic motion.

Color palette should stay within this range:
#E9ECEC, #C9D2D4, #8C9A9E, #44545B, #11171B.
```
