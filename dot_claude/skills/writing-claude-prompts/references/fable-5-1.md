# Claude Fable 5.1 (and Mythos 5.1)

Source: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1>
Fetched: 2026-09-29
Builds on: [`fable-5.md`](fable-5.md). Fable 5 prompts carry over; the differences are below.

Thinking is always on. Effort defaults to `high`. Re-run the effort sweep even if you ran one on Fable 5: `medium` roughly matches Fable 5 at lower cost, and `low` is often competitive on cost with Opus and Sonnet while scoring higher. Fable 5.1 runs safety classifiers and can return `stop_reason: "refusal"`.

Two differences point the **opposite** way from older advice: Fable 5.1 writes *fewer* progress updates than Fable 5, and it formats *less* than earlier models. Anti-narration and anti-formatting lines written for earlier models now over-suppress.

## Symptoms and fixes

| You see | Fix |
|---|---|
| Latency or cost higher than the task warrants | Sweep all effort levels from `high` down. |
| Little or no text between tool calls; final message covers only the last step | Set `display: "updates"` (or `"summarized"`) so progress blocks reach the client. Remove "hold all findings for the final response"-style lines. Then add the progress-update line. If your UI hides tool output, tell the model in a turn-scoped system message. |
| One tool call per turn in coding or computer-use loops | Append the batching nudge after each round of tool results as a turn-scoped system message; leave earlier copies in place byte-for-byte. |
| `bound to a different conversation` errors, or the harness edits earlier turns | Keep history append-only: pass each assistant turn back as returned, thinking blocks included. Use turn-scoped system messages for per-turn reminders, mid-conversation system messages for instruction or tool changes, and server-side compaction or context editing for trimming. For client compaction, replace the whole history with one summary plus the new user turn. |
| Prose runs long and dense | Add the mannered-prose definition (prefer the user message) or its one-line version. |
| Chat replies carry less structure than the content needs | Remove anti-formatting blocks; replace with the when-to-format rule. |
| Summaries reproduce source wording unmarked | Add one complete correct example with a rationale (below). |
| Stops before the work is done, or asks permission for requested work | Add both "finish the whole task" blocks. Keep the opening "not watching" sentence as written. |
| Client-side compaction drops constraints or exact details | Use the summarization instruction below. |
| Unrequested fixes, extensions, or extra committed tests | Add the keep-changes-scoped instruction. |
| Answers from memory at `low` instead of searching | Raise effort for those turns, or add the search-the-name instruction. |
| Benign coding requests refused | Ask "Are there any bugs in this program?" instead of "Does this compile?"; give docs for lesser-known languages; remove base64 from tool output. |
| Rewrites whole files for small edits | Add the targeted-edit line. |
| `xhigh`/`max` drafts the deliverable in thinking, then again in the reply | Run long deliverables at `high`. At `xhigh`/`max`, size `max_tokens` for both and append the one-limit note to the user message. |
| Lead agent idles while subagents run | Make subagent-start tools return immediately, deliver results in later user messages, and give the lead a separate wait tool. |
| Dense charts miss detail | Container with PIL/OpenCV, or at least a crop-and-enlarge tool. |

## Recommended snippets (verbatim)

Progress updates:

```text
Before you start, say in a line what you're about to do; brief updates while you work help the user follow along. Close with a short recap that stands on its own — what you found, what you did, and what's next — so a reader who only sees the last message has the full picture.
```

Hidden tool output (turn-scoped system message):

```text
Only you see that command's output — the user's terminal shows at most a few lines of it. If the user needs to read any of it, put it in your reply.
```

Batch independent tool calls (turn-scoped system message after each round of tool results; without the beta, a text block after the `tool_result` blocks):

```text
First privately list what you need next; then request every item that doesn't depend on another's result in this one response.
```

Writing density, long form and short form:

```text
Mannered prose substitutes metaphor and flourish for direct statement. Instead of "a parameter worth varying," the mannered writer produces "a dial worth turning." Instead of "this point still matters," they write "this point earns its keep." The phrases exist to display the writer, not to convey the idea, and readers can tell. That is why mannered prose irritates: it makes the reader work harder so the writer can perform. It is also imprecise. Metaphors drag in connotations the writer did not choose and cannot control. The fix is to say what you mean. When a literal phrase is available, use it.
```

```text
Please remove all mannered prose.
```

Formatting in chat:

```text
Use lists and bullet points when asked to, or when the content is multifaceted enough that they help with clarity. If the person explicitly requests minimal formatting, always format your responses without bullet points, headers, lists, or bold emphasis, as requested. In conversational, personal, or emotional exchanges, keep to plain prose.
```

Quoting retrieved sources: one complete example with a rationale. Replace the `[web_search: ...]` lines with your own tool's name.

```text
<example>
<user>look up how the Riverton Ledger and the Coast Dispatch each covered the Harbor Bridge closure and compare their reporting</user>
<response>
[web_search: Harbor Bridge closure Riverton Ledger]
[web_search: Harbor Bridge closure Coast Dispatch]
Both outlets agree on the basics: the bridge closed on March 3 after inspectors found cracked welds, and the state expects repairs to take about eight months. Where they differ is emphasis. The Ledger treats it as a local-economy story. The Dispatch frames it as a funding failure; its editorial calls the closure "entirely foreseeable." Read together, the Ledger explains who is affected now and the Dispatch explains how it came to this — neither account alone gives the whole picture.
</response>
<rationale>CORRECT: The response is organized around where the two outlets agree and differ, not as a walk through either article. Each outlet's reporting is conveyed in one or two sentences of the assistant's own indirect speech. One short marked phrase from one source; every other claim is reworded. The response is still specific and complete.</rationale>
</example>
```

Finish the whole task, block one (keeps most of the effect alone). The opening "not watching" sentence carries much of it; keep it as written, and add a sentence after it listing any confirmations your product needs:

```text
You are operating autonomously. The user is not watching in real time and cannot answer questions mid-task, so asking 'Want me to…?' or 'Shall I…?' will block the work. For reversible actions that follow from the original request, proceed without asking. Stop only for destructive actions or genuine scope changes the user must decide. Offering follow-ups after the task is done is fine; asking permission before doing the work is not.

Exception: when the user is describing a problem, asking a question, or thinking out loud rather than requesting a change, the deliverable is your assessment. Report your findings and stop. Don't apply a fix until they ask for one.

Before ending your turn, check your last paragraph. If it is a plan, an analysis, a question, a list of next steps, or a promise about work you have not done ('I'll…', 'let me know when…'), do that work now with tool calls. That includes retrying after errors and gathering missing information yourself. Do not stop because the context or session is long. End your turn only when the task is complete or you are blocked on input only the user can provide.

Before running a command that changes system state (such as restarts, deletes, or config edits), check that the evidence actually supports that specific action. A signal that pattern-matches to a known failure may have a different cause.
```

Finish the whole task, block two (the request is the scope):

```text
# Delivering work
The user's request — or the plan they approved — sets the scope, and the scope is the deliverable: don't quietly narrow, widen, or swap it. Read ambiguity the way a careful colleague would: make routine judgment calls yourself, and check in only when different readings would lead to materially different work. If you see a real problem with the task as specified, say so in a sentence or two and keep building under stated assumptions; if the user hears the concern and reaffirms, that is their decision, so deliver the full request.

If a question comes up partway, first do everything that doesn't depend on the answer; then state the assumption you made, or — when going ahead on a wrong guess would be unsafe or would make the work useless — put the question at the end of a turn that also delivers that progress. If one part turns out to be blocked, complete every other part in full and say exactly what you left out and why — the whole task is the deliverable, and scaling it down is the user's call, not yours. A step you have decided on is something to run, not to announce: describing the next step and ending the turn leaves it undone until the user replies.

Keep changes to what the request needs. Something else you notice worth doing — cleanup or documentation the task didn't call for, a change to a file the task didn't require — is a suggestion to make at the end, not a change to make; actions clearly beyond what the ask implies, and risky or destructive ones, still need the user's go-ahead.
```

Client-side compaction summaries:

```text
Summarize the transcript inside <summary></summary> tags. Include relevant information in the summary such that this conversation will be continued by a new context window without needing to redo work or be reprovided with relevant constraints or context. Be sure to preserve: (1) any difficulties or problems that came up, and how they were handled or resolved; (2) any possibilities, options, or approaches that were raised, tried, or set aside, and why; (3) anything that was asked for, decided, agreed, ruled out, or established as a preference, constraint, or boundary — stated exactly; (4) exactly where things stand now — what has been covered, settled, or completed so far; (5) anything still open, unresolved, promised, or expected to happen next; (6) specific details that would be hard to reconstruct — names, numbers, dates, exact wording, links or references — kept exactly. Be complete on these even at the cost of length; keep everything else concise. Weight the two voices differently: keep what the user said, asked for, shared, or established carefully and close to their own words; your own explanations and reasoning can be condensed much further, to what they concluded or produced — as long as nothing in the six items above is dropped.
```

Keep changes and tests scoped:

```text
If, while working or testing, you find a pre-existing bug, a performance concern, or behavior the task doesn't mention, don't fix, optimize or extend it in this change unless the requested behavior cannot work without it; report it as a follow-up in your summary. Where the task is ambiguous, implement the reading its wording and the surrounding code most directly support, state that assumption in your summary, and don't build for the other readings as well. Verify your work however you like; scratch scripts and quick checks need not be kept. Commit tests only where the task asks for them or this repository already keeps tests for this kind of change, sized like the neighboring test files — roughly one focused test per stated behavior — and don't turn scratch checks into additional permanent test files. This is about extras only: implement every behavior the task asks for, completely.
```

Search triggering at low effort:

```text
When a query centers on a name you do not confidently recognize, or recognize from a fast-moving area like AI models and developer tools where the landscape shifts within months, the name itself is the thing to verify: search before answering, and include the name as the user wrote it in at least one query alongside any reformulations. This holds even when you have some background on it — partial background is exactly what makes an out-of-date answer sound authoritative, so familiarity is not a reason to skip the search.
```

Targeted edits:

```text
The number of tokens used to edit files is best minimized, all else being equal. Therefore, when it will not affect the end result, try to surgically edit a file rather than rewrite the entire thing.
```

Long outputs at `xhigh`/`max` (end of the user message; replace `[max_tokens]` with the real value):

```text
Everything produced in one reply, including any reasoning or drafting done before the reply, counts toward a single limit of about [max_tokens] tokens. If that limit is reached before the reply is finished, the person receives a cut-off response and has to start over. Composing an entire output or deliverable in full as reasoning and then again as a reply would double the length of the turn without improving the result, so don't do that.

Instead, when the person has asked for a long or effort-intensive deliverable such as a multi-section document, a large table or dataset, or a complete code file, spend extra effort on understanding the request, checking the inputs the answer depends on, settling the structure and other difficult decisions, and otherwise using the reasoning space to reason and the output space to write an output. Usually it is not needed to draft an output multiple times.
```
