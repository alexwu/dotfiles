# Prompting best practices (all current models)

Sources:
- <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices>
- <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview>

Fetched: 2026-09-29

The general guide covers Fable 5.1/5, Mythos 5.1/5, Opus 5.5/5/4.8/4.7/4.6, Sonnet 5.5/5/4.6, and Haiku 4.5. Where it names a model, treat the advice as measured on that model and re-check it on others. The model-specific references in this directory override it where they disagree.

Before tuning a prompt, have success criteria, a way to test against them, and a first draft (the overview's three prerequisites). Some failures are cheaper to fix by switching models than by prompting.

## Principles

**Be explicit.** Treat Claude like a brilliant new employee who lacks your context. Golden rule: if a colleague with minimal context would be confused by the prompt, Claude will be too. Ask for "above and beyond" outright; it won't infer it. Use numbered steps when order or completeness matters.

**Give the reason.** A rule with its motivation generalizes; a bare rule doesn't. The guide's example: "NEVER use ellipses" is weaker than explaining that a text-to-speech engine will read the output and can't pronounce them.

**Examples steer hardest.** Make them relevant, diverse enough that Claude doesn't copy incidental patterns, and wrapped in `<example>` / `<examples>` tags so they read as examples rather than instructions.

**Structure with XML tags.** Separate instructions, context, examples, and inputs into their own consistently named tags. Nest when content is hierarchical (`<documents>` → `<document index="n">` with `<source>` and `<document_content>`).

**Set a role.** One sentence in the system prompt focuses behavior and tone.

**Long context (20k+ tokens).** Put long documents at the top, above the instructions and query. Wrap each document in XML with its metadata. For long-document tasks, ask Claude to quote the relevant parts first, then work from the quotes.

**Say what to do, not what to avoid.** "Your response should be composed of smoothly flowing prose paragraphs" beats "Do not use markdown". Matching the prompt's own style to the output you want also works: a markdown-heavy prompt draws markdown-heavy replies.

**Dial back emphasis for current models.** Prompts written to fix under-triggering on older models now over-trigger. Replace "CRITICAL: You MUST use this tool when..." with "Use this tool when...". Replace "If in doubt, use [tool]" and "Default to using [tool]" with targeted guidance about when the tool helps.

**Action vs suggestion is literal.** "Can you suggest some changes" gets suggestions. "Change this function" gets changes. Set the default in the system prompt if needed (snippets below).

**Thinking guidance.** General instructions ("think thoroughly") often beat hand-written step plans. `<thinking>` tags inside few-shot examples teach a reasoning style. Self-check instructions help most models, **except** Opus 5, where they cause over-verification (see [`opus-5.md`](opus-5.md)). Never ask a thinking-always-on model to write its reasoning into the response; read the thinking blocks.

**Prefill is gone.** Prefilling the last assistant turn returns a 400 on Claude 4.6 models and later. Replace each use:
- Format forcing → Structured Outputs, or tools with an enum for classification.
- Preamble removal → "Respond directly without preamble. Do not start with phrases like 'Here is...', 'Based on...', etc." or XML output tags.
- Continuations → move the partial text into the user turn ("Your previous response was interrupted and ended with `[previous_response]`. Continue from where you left off.").
- Periodic context hydration → inject reminders in the user turn, through tools, or at compaction; on current models, use mid-conversation system messages (see [`mid-conversation-system-messages.md`](mid-conversation-system-messages.md)).

**Keep history append-only on Fable 5.1, Opus 5.5, and Sonnet 5.5.** Editing earlier messages, rebuilding `system` or `tools`, or summarizing older turns in place invalidates later thinking blocks. Move those changes into mid-conversation system messages and server-side context management.

## Model defaults the guide calls out

- Latest models are more concise and skip post-tool summaries. Ask for a summary if you want one. Opus 5 is the exception (runs long; prompt for brevity). Fable 5.1 writes fewer updates between tool calls (ask for them, and drop "keep updates brief" lines).
- LaTeX is the default for math; ask for plain text if you need it.
- Adaptive thinking is the mode on 4.6 and later. `budget_tokens` returns a 400 on 4.7 and later; use `effort` and `max_tokens`. Thinking is off by default on Opus 4.6–4.8 and Sonnet 4.6, on by default on Opus 5 and Sonnet 5/5.5, and always on for Fable 5.1/5, Mythos 5.1/5, and Opus 5.5.
- Opus 4.6 over-explores at high effort and over-spawns subagents; Opus 4.5/4.6 over-engineer. Use the damping snippets below.
- Sonnet 5, Sonnet 4.6, Sonnet 4.5, and Haiku 4.5 track their remaining context. In a harness that compacts, tell them so they don't wrap up early.

## Recommended snippets (verbatim)

Proactive action by default:

```text
<default_to_action>
By default, implement changes rather than only suggesting them. If the user's intent is
unclear, infer the most useful likely action and proceed, using tools to discover any
missing details instead of guessing. Try to infer the user's intent about whether a tool
call (e.g., file edit or read) is intended or not, and act accordingly.
</default_to_action>
```

Conservative action by default:

```text
<do_not_act_before_instructions>
Do not jump into implementation or change files unless clearly instructed to make
changes. When the user's intent is ambiguous, default to providing information, doing
research, and providing recommendations rather than taking action. Only proceed with
edits, modifications, or implementations when the user explicitly requests them.
</do_not_act_before_instructions>
```

Parallel tool calls (on Fable 5.1 in long loops, send the batching nudge from [`fable-5-1.md`](fable-5-1.md) instead):

```text
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool
calls, make all of the independent tool calls in parallel. Prioritize calling tools
simultaneously whenever the actions can be done in parallel rather than sequentially.
For example, when reading 3 files, run 3 tool calls in parallel to read all 3 files into
context at the same time. Maximize use of parallel tool calls where possible to increase
speed and efficiency. However, if some tool calls depend on previous calls to inform
dependent values like the parameters, do NOT call these tools in parallel and instead
call them sequentially. Never use placeholders or guess missing parameters in tool
calls.
</use_parallel_tool_calls>
```

Post-tool summary:

```text
After completing a task that involves tool use, provide a quick summary of the work you've done.
```

Minimize markdown (not on Fable 5.1, which already formats less; use its formatting rule instead):

````text
<avoid_excessive_markdown_and_bullet_points>
When writing reports, documents, technical explanations, analyses, or any long-form
content, write in clear, flowing prose using complete paragraphs and sentences. Use
standard paragraph breaks for organization and reserve markdown primarily for `inline
code`, code blocks (```...```), and simple headings (## and ###). Avoid using **bold**
and *italics*.

DO NOT use ordered lists (1. ...) or unordered lists (*) unless: a) you're presenting
truly discrete items where a list format is the best option, or b) the user explicitly
requests a list or ranking

Instead of listing items with bullets or numbers, incorporate them naturally into
sentences. This guidance applies especially to technical writing. Using prose instead of
excessive formatting will improve user satisfaction. NEVER output a series of overly
short bullet points.

Your goal is readable, flowing text that guides the reader naturally through ideas
rather than fragmenting information into isolated points.
</avoid_excessive_markdown_and_bullet_points>
````

Plain-text math:

```text
Format your response in plain text only. Do not use LaTeX, MathJax, or any markup
notation such as \( \), $, or \frac{}{}. Write all math expressions using standard text
characters (e.g., "/" for division, "*" for multiplication, and "^" for exponents).
```

Commit to an approach (overthinking):

```text
When you're deciding how to approach a problem, choose an approach and commit to it.
Avoid revisiting decisions unless you encounter new information that directly
contradicts your reasoning. If you're weighing two approaches, pick one and see it
through. You can always course-correct later if the chosen approach fails.
```

Reflect after tool results:

```text
After receiving tool results, carefully reflect on their quality and determine optimal
next steps before proceeding. Use your thinking to plan and iterate based on this new
information, and then take the best next action.
```

Think less often:

```text
Thinking adds latency and should only be used when it will meaningfully improve
answer quality - typically for problems that require multistep reasoning. When in
doubt, respond directly.
```

Context compaction in a harness:

```text
Your context window will be automatically compacted as it approaches its limit, allowing
you to continue working indefinitely from where you left off. Therefore, do not stop
tasks early due to token budget concerns. As you approach your token budget limit, save
your current progress and state to memory before the context window refreshes. Always be
as persistent and autonomous as possible and complete tasks fully, even if the end of
your budget is approaching. Never artificially stop any task early regardless of the
context remaining.
```

Use the whole context on long tasks:

```text
This is a very long task, so it may be beneficial to plan out your work clearly. It's
encouraged to spend your entire output context working on the task - just make sure you
don't run out of context with significant uncommitted work. Continue working
systematically until you have completed this task.
```

Multi-window workflows: use a different prompt for the first window (set up tests and scripts), track tests in a structured file (`tests.json`), keep freeform notes (`progress.txt`), use git as the state log, and tell a fresh window how to start ("Call pwd; you can only read and write files in this directory." / "Review progress.txt, tests.json, and the git logs.").

Reversibility and safety:

```text
Consider the reversibility and potential impact of your actions. You are encouraged to
take local, reversible actions like editing files or running tests, but for actions that
are hard to reverse, affect shared systems, or could be destructive, ask the user before
proceeding.

Examples of actions that warrant confirmation:
- Destructive operations: deleting files or branches, dropping database tables, rm -rf
- Hard to reverse operations: git push --force, git reset --hard, amending published commits
- Operations visible to others: pushing code, commenting on PRs/issues, sending
messages, modifying shared infrastructure

When encountering obstacles, do not use destructive actions as a shortcut. For example,
don't bypass safety checks (e.g. --no-verify) or discard unfamiliar files that may be
in-progress work.
```

Structured research:

```text
Search for this information in a structured way. As you gather data, develop several
competing hypotheses. Track your confidence levels in your progress notes to improve
calibration. Regularly self-critique your approach and plan. Update a hypothesis tree or
research notes file to persist information and provide transparency. Break down this
complex research task systematically.
```

Subagent usage:

```text
Use subagents when tasks can run in parallel, require isolated context, or involve
independent workstreams that don't need to share state. For simple tasks, sequential
operations, single-file edits, or tasks where you need to maintain context across steps,
work directly rather than delegating.
```

Clean up scratch files:

```text
If you create any temporary new files, scripts, or helper files for iteration, clean up
these files by removing them at the end of the task.
```

Minimize over-engineering:

```text
Avoid over-engineering. Only make changes that are directly requested or clearly
necessary. Keep solutions simple and focused:

- Scope: Don't add features, refactor code, or make "improvements" beyond what was
asked. A bug fix doesn't need surrounding code cleaned up. A simple feature doesn't need
extra configurability.

- Documentation: Don't add docstrings, comments, or type annotations to code you didn't
change. Only add comments where the logic isn't self-evident.

- Defensive coding: Don't add error handling, fallbacks, or validation for scenarios
that can't happen. Trust internal code and framework guarantees. Only validate at system
boundaries (user input, external APIs).

- Abstractions: Don't create helpers, utilities, or abstractions for one-time
operations. Don't design for hypothetical future requirements. The right amount of
complexity is the minimum needed for the current task.
```

General solutions over test-passing:

```text
Please write a high-quality, general-purpose solution using the standard tools
available. Do not create helper scripts or workarounds to accomplish the task more
efficiently. Implement a solution that works correctly for all valid inputs, not just
the test cases. Do not hard-code values or create solutions that only work for specific
test inputs. Instead, implement the actual logic that solves the problem generally.

Focus on understanding the problem requirements and implementing the correct algorithm.
Tests are there to verify correctness, not to define the solution. Provide a principled
implementation that follows best practices and software design principles.

If the task is unreasonable or infeasible, or if any of the tests are incorrect, please
inform me rather than working around them. The solution should be robust, maintainable,
and extendable.
```

Investigate before answering:

```text
<investigate_before_answering>
Never speculate about code you have not opened. If the user references a specific file,
you MUST read the file before answering. Make sure to investigate and read relevant
files BEFORE answering questions about the codebase. Never make any claims about code
before investigating unless you are certain of the correct answer - give grounded and
hallucination-free answers.
</investigate_before_answering>
```

Model identity:

```text
The assistant is Claude, created by Anthropic. The current model is Claude Opus 5.5.
```

```text
When an LLM is needed, please default to Claude Opus 5.5 unless the user requests
otherwise. The exact model string for Claude Opus 5.5 is claude-opus-5-5.
```

Frontend aesthetics, long form (written for Opus 4.5/4.6; Opus 4.8 and later need only the short form in [`opus-4-8.md`](opus-4-8.md)):

```text
<frontend_aesthetics>
You tend to converge toward generic, "on distribution" outputs. In frontend design, this
creates what users call the "AI slop" aesthetic. Avoid this: make creative, distinctive
frontends that surprise and delight.

Focus on:
- Typography: Choose fonts that are beautiful, unique, and interesting. Avoid generic
fonts like Arial and Inter; opt instead for distinctive choices that elevate the
frontend's aesthetics.
- Color & Theme: Commit to a cohesive aesthetic. Use CSS variables for consistency.
Dominant colors with sharp accents outperform timid, evenly-distributed palettes. Draw
from IDE themes and cultural aesthetics for inspiration.
- Motion: Use animations for effects and micro-interactions. Prioritize CSS-only
solutions for HTML. Use Motion library for React when available. Focus on high-impact
moments: one well-orchestrated page load with staggered reveals (animation-delay)
creates more delight than scattered micro-interactions.
- Backgrounds: Create atmosphere and depth rather than defaulting to solid colors. Layer
CSS gradients, use geometric patterns, or add contextual effects that match the overall
aesthetic.

Avoid generic AI-generated aesthetics:
- Overused font families (Inter, Roboto, Arial, system fonts)
- Clichéd color schemes (particularly purple gradients on white backgrounds)
- Predictable layouts and component patterns
- Cookie-cutter design that lacks context-specific character

Interpret creatively and make unexpected choices that feel genuinely designed for the
context. Vary between light and dark themes, different fonts, different aesthetics. You
still tend to converge on common choices (Space Grotesk, for example) across
generations. Avoid this: it is critical that you think outside the box!
</frontend_aesthetics>
```

Document creation:

```text
Create a professional presentation on [topic]. Include thoughtful design elements,
visual hierarchy, and engaging animations where appropriate.
```

Parallel execution damping:

```text
Execute operations sequentially with brief pauses between each step to ensure stability.
```
