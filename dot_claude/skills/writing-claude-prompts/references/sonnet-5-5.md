# Claude Sonnet 5.5

Source: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5>
Fetched: 2026-09-29
Builds on: [`sonnet-5.md`](sonnet-5.md). Sonnet 5 prompts carry over without changes. For the hardest long-horizon work, the guide points to an Opus model instead.

Effort levels are recalibrated and don't match Sonnet 5's. The API default is `high`. Start at `medium` for well-specified agentic coding, and at `medium` or `low` for chat and latency-sensitive work. The lowest thinking setting is `thinking: {"type": "between_tools"}`, accepted only at `high` or below. From `medium` up, the model thinks briefly before almost every reply, and asking it to think less doesn't reliably work; lower the effort instead.

## Symptoms and fixes

| You see | Fix |
|---|---|
| Unsure which effort, or turn lengths changed | Run a fresh sweep. At `low` it may skip verification; at `low`/`medium` it checks in early on long agentic tasks. Set `max_tokens` to 128,000 for agentic coding and stream. |
| Stops to check in before a coding task is done | Raise effort, or add the carry-through prompt below (both paragraphs). Sessions at low effort then run longer. Keep your own risky-action rules. |
| Adds tests, docs, and small files you didn't ask for | Add only the second paragraph of the carry-through prompt ("When the work the user asked for is done..."). |
| Self-started review rounds and reviewer subagents at `xhigh`/`max` | Run routine work at `high`. To keep the thoroughness but aim it at the task, add the stop-and-report prompt below (cut session cost about a third at `max`). |
| Builds a deck or video when you wanted ideas | Say you want ideas first, or add the ideas-and-stop prompt. |
| Integration ran with thinking off | Switch to `between_tools`, send it at `high` or below, don't change effort mid-conversation under it, remove "don't think" rules (they cause internal-tag leaks), read the response by block type, and pass thinking blocks back unchanged. Use adaptive thinking for reasoning tasks without tools. |
| JSON answers to multi-step reasoning tasks are wrong or unparseable | Use structured outputs where available. With adaptive thinking, add "Think the problem through before you answer." at the end of the system prompt, or use `xhigh`. Don't use `between_tools` here. Treat `stop_reason: "max_tokens"` as failure even if the JSON is valid. Without structured outputs, parse the **last** JSON value in the text blocks (never first `{` to last `}`), check its fields, retry once. |
| Long agentic turns look silent | Set `display: "updates"`. Remove old "hold all findings for the final response" lines. Ask for updates at set points. As a last lever, append the quiet-turn reminder as a turn-scoped system message after five quiet steps; stop after two or three. |
| Answers from training knowledge when a search would catch changes | Remove "only use tools when strictly necessary"-style lines, then add the search prompt below. |
| Mid-task user messages treated as injected text | Never put user text inside a `tool_result`. Append the user's words as a text block after the last `tool_result` in the same user message. Keep harness notices in a separate system message after the user's words. Drop per-step token countdowns in interactive sessions. |
| Reports code changes done without running a check | Add the verification paragraph below (makes skipped checks rare at `low`). |
| Calls `bash` for `Bash`, or near-miss parameter names | Accept unambiguous case mismatches in the harness, or return `is_error: true` stating the exact name. |
| Dense charts and drawings miss detail | Give crop/zoom/code tools. On charts, tools at `high` beat no tools at `max`. |
| `stop_reason: "refusal"` | Categories: `cyber`, `bio`, `frontier_llm`, `reasoning_extraction`, `general_harms`. Remove instructions that ask for reasoning in the response text; read summarized thinking blocks instead. |

Frequent harness text after tool results makes the model suspect prompt injection. Keep reminders occasional.

## Recommended snippets (verbatim)

Carry work through (both paragraphs), or use the second paragraph alone to stop unrequested additions:

```text
Keep working until everything the user asked for is done, and only stop to ask when you can't go on without the user or before a risky step.

When the work the user asked for is done and checked, stop and report. Don't add features, tests, files, docs or refactors that weren't asked for. If you think one would help, mention it at the end instead of doing it.
```

Aim `xhigh`/`max` thoroughness at the task:

```text
When the work the user asked for is done and its checks pass, stop and report. Don't start extra rounds of review or hardening on your own, and don't launch reviewer sub-agents unless the user asked for a review. If you think a deeper review is worth doing, say so at the end.
```

Ideas before building:

```text
When the user asks for ideas, options or a plan, give them that and stop. Don't start building or changing anything until they say to go ahead.
```

Reasoning before a JSON answer (end of system prompt, adaptive thinking):

```text
Think the problem through before you answer.
```

Quiet-turn reminder (turn-scoped system message):

```text
The user hasn't heard from you in a while — say in a few words what you're doing, then continue.
```

Search for current specifics:

```text
Use the search tool to check specifics that may have changed since your training, such as what is allowed, required or charged, even when you feel confident. For researched work such as a report or a comparison, gather current sources rather than writing from your training knowledge.
```

Verification on coding tasks:

```text
When you change code that can be run, built, or type-checked, run a real check that exercises the change before reporting it done: the project's tests, type-checker, or build, or the changed command itself. A syntax-only check, or a check command that failed to start, does not count; if all that is missing is the project's declared dependencies, install them with its own package manager and lockfile (e.g. npm install, pip install -r requirements.txt), never via sudo or the system package manager, unless told not to. Only if no real check can run here, say which one you did not run and why instead of reporting the change as done.
```
