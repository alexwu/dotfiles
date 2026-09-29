---
name: writing-claude-prompts
description: >
  Write, revise, or debug prompts that run on current Claude models (Fable, Opus,
  Sonnet 5.x and Opus 4.8): system prompts, persona and character prompts,
  CLAUDE.md and AGENTS.md files, subagent definitions, and hook, anchor, or
  reminder bodies injected mid-session. Use when drafting any of these, when
  porting a prompt to a newer model, or when a model misbehaves in a way prompt
  wording might cause: refusing or dropping a persona, over-verifying, going
  silent between tool calls, ignoring scope, over- or under-formatting, stopping
  early, or copying examples verbatim. Also use to maintain this skill itself:
  "update the prompting skill", "refresh the prompting docs", "check for new
  model guides". Not for Anthropic SDK or API code (claude-api), SKILL.md
  structure (writing-agent-skills), or auditing where CLAUDE.md content belongs
  (claude-md-improver).
---

# Writing Claude Prompts

A prompt for a current Claude model is tuned to that model: the same line that fixes Opus 4.8 wastes tokens on Opus 5 and over-suppresses Fable 5.1. This skill holds Anthropic's per-model guidance, distilled, plus what our own A/B runs have shown. Load `writing-english` too. Prompt prose is prose, and its rules (lead with the point, positive form, concrete words) are the same ones the model guides keep arriving at.

## Workflow

1. **Name the target model and where the text lands.** Both change the advice. See the two tables below.
2. **Read the reference for each target model**, and `references/field-notes.md` if the prompt carries a persona, identity, or injected context.
3. **Audit before adding.** On an existing prompt, first remove lines the target model no longer needs (see "Remove legacy scaffolding"). Then add the fixes.
4. **Draft against the principles below.** Where a reference offers a snippet for the exact symptom, use it word for word. The docs call these tested wording; paraphrase loses the test.
5. **Test with counts, not impressions.** Run each variant at least 3 to 5 times on the same input and compare tallies. A model's explanation of why it did something is a lead to test, never the diagnosis.

## Which model, which quirks

| Model | Thinking | Default effort | Lead quirks to prompt for | Reference |
|---|---|---|---|---|
| Fable 5.1 / Mythos 5.1 | always on | `high` | Writes *fewer* progress updates and formats *less* than earlier models; one tool call per turn in coding loops; dense prose; stops early on long async work; rewrites whole files | `references/fable-5-1.md` |
| Fable 5 / Mythos 5 | always on | `high` | Brief instructions steer whole classes of behavior; old prescriptive prompts degrade it; fabricated progress on long runs unless told to audit claims | `references/fable-5.md` |
| Opus 5.5 | always on | `medium` | Thinks more per turn than Opus 5 at the same level; unattended loops stop after reporting; strong prompt-injection resistance (mark pasted text); persona takes at operator tier only | `references/opus-5-5.md` |
| Opus 5 | on (off only at ≤ `high`) | `high` | Verbose; over-verifies when told to verify; widens scope; delegates to subagents readily; tags leak with thinking off | `references/opus-5.md` |
| Opus 4.8 | off unless set | use `xhigh` for coding | Literal; favors reasoning over tools; spawns few subagents; persistent cream/serif design house style | `references/opus-4-8.md` |
| Sonnet 5.5 | on; `between_tools` lowest | `high` (API) | Recalibrated effort; checks in early at low effort, adds extras at high; skips thinking before JSON answers; misreads frequent harness text as injection | `references/sonnet-5-5.md` |
| Sonnet 5 | on by default | `high` | Literal at low effort; no `temperature`; no mid-conversation system messages | `references/sonnet-5.md` |
| Haiku 4.5, Sonnet 4.6, older | varies | varies | No dedicated guide; use the general guide | `references/best-practices.md` |

Effort names don't map across models. A level on one model is not the same amount of thinking on another, so re-sweep effort on every upgrade rather than carrying the setting over.

## Where the text lands

| Surface | How the model weighs it | Notes |
|---|---|---|
| System prompt, `--append-system-prompt-file`, API `system` | Operator | Put identity, persona, and standing policy here. |
| `CLAUDE.md` / `AGENTS.md` in Claude Code | User tier | Opus 5.5 wouldn't take a persona from here reliably (field notes). Good for project conventions, weak for identity. |
| Custom subagent definition body | That subagent's system prompt | Write it as a standalone operator prompt; the subagent sees none of the parent's context. |
| Agent tool `prompt` / task message | User turn | Give the reason and the full spec up front; current models do best when they're left to run. |
| Hook `additionalContext`, anchors, reminders | Injected mid-conversation | Wrap it in a tag the system prompt defines as trusted. State facts rather than commands, and keep it occasional. See `references/mid-conversation-system-messages.md`. |
| API mid-conversation `role: "system"` message | Operator, from that point on | Append; never edit or delete one already sent. Not available on Sonnet 5. |

## Principles that hold across current models

**Say what to write, not what to avoid.** Every prohibition gets the behavior you want next to it. A bare "don't" plants the failure it names. The model also satisfies it at its narrowest reading: told not to say the number, it said "the count" (field notes).

**Give the reason.** A rule with its motivation generalizes; a bare rule gets applied literally, to the one case it names.

**One brief general instruction beats a list of cases.** Fable 5 and later steer a whole class of behavior from a sentence. Prompts written for older models are often too prescriptive and can make output worse. Current models over-trigger on emphatic language: write "Use this tool when...", not "CRITICAL: You MUST...".

**State scope explicitly.** Opus 4.8 and the Sonnet 5 line read literally and won't generalize an instruction from one item to the rest. Review prompts that say "only report high-severity issues" get followed exactly, and recall drops. Ask for coverage and filter in a later pass.

**Examples steer hardest, and they get copied.** Use at least three varied examples per behavior, wrapped in `<example>` tags. Keep scenario facts in the example's context, not its response, or the examples teach fabrication. Never put sample phrasing in a list of options.

**Frame persona and identity as the author's choice.** State who wrote the prompt and for whom, and that the model keeps its own judgment. Cut lines that read as levers on the model, bans on explaining itself, or demands to deny being an AI. Opus 5.5 reads those as jailbreak-shaped (field notes).

**Effort controls thinking; prompts barely do.** To get less thinking, lower effort. Never ask a thinking-always-on model to write its reasoning into the response: that invites `reasoning_extraction` refusals. Read the thinking blocks instead.

**Keep history append-only on Fable 5.1, Opus 5.5, and Sonnet 5.5.** Editing earlier turns, `system`, or `tools` mid-session breaks prompt caching and invalidates later thinking blocks. Deliver changes and reminders as appended system messages.

### Remove legacy scaffolding

When porting a prompt forward, delete these before adding anything:

- Verification and double-check instructions (Opus 5 over-verifies with them).
- "Hold all findings for the final response" and "keep updates brief" (Fable 5.1 and Sonnet 5.5 already under-narrate).
- Anti-markdown and anti-bullet blocks (Fable 5.1 already under-formats).
- "Think carefully before answering" in chat prompts (Opus 5.5: slower, no better).
- "Don't think" or "don't reason" rules (they cause internal-tag leaks).
- "Only use tools when strictly necessary" (Sonnet 5.5 then answers from stale memory).
- "After every N tool calls, summarize" (Opus 4.8 and Sonnet 5 update well on their own).
- Show-your-reasoning and echo-your-thinking instructions (`reasoning_extraction`).
- Visible remaining-token countdowns (Fable 5 starts suggesting new sessions).

## Gotchas

- **A reminder that re-fires beats the base prompt.** An anchor or hook body injected every N turns wins wherever it disagrees with the system prompt. Keep the two consistent word for word on shared rules.
- **Test injected text the way the harness delivers it.** Concatenating an anchor onto the system prompt produces artifacts that vanish when it arrives as hook context. In lulu-prompts, `just test` runs without hooks, so inject the body in the user turn with the `SessionStart hook additional context:` prefix.
- **A rule that points at context the harness doesn't supply invites invention.** Told to read a cwd it didn't have, the model invented an injected-context tag.
- **Frames and hidden parameters recite themselves.** Tell the model how a premise or a dice roll should *show*, or it will print it.
- **Count tokens with the Anthropic tokenizer** (`tokens -p anthropic -m <model> --prompt-file FILE < /dev/null`). The o200k count runs about 35% low.

## References (load on demand)

- `references/<model>.md` (`fable-5-1`, `fable-5`, `opus-5-5`, `opus-5`, `opus-4-8`, `sonnet-5-5`, `sonnet-5`). **Load** the one for each target model before drafting or debugging, and the file its header says it builds on when porting across versions. Each maps symptoms to fixes and quotes the recommended snippets verbatim.
- `references/best-practices.md`: the general guide (XML structure, long context, prefill migration, tool and action defaults, research, agentic state) with its snippets. **Load** for a model without its own guide, or when a technique isn't model-specific.
- `references/mid-conversation-system-messages.md`: the API mechanism behind reminders and injected instructions, and how to word them. **Load** when writing a hook body, anchor, reminder, or relayed user message.
- `references/field-notes.md`: lessons from our own A/B runs and commits that the docs don't cover. **Load** for persona, identity, or injected-context work, and before overriding any of its entries.
- `references/sources.md`: the manifest of every source page, what it feeds, and when it was fetched. **Load** when refreshing this skill.

## Refreshing this skill

Follow this when asked to update the prompting skill, refresh the docs, or check for new model guides.

1. From the chezmoi source repo, run `just refresh-prompting-docs`. It re-scrapes every page in `references/sources.md` into `.firecrawl/<slug>.md`, prints a unified diff against the previous scrape, and lists pages under the prompt-engineering index that the manifest lacks. It fetches and diffs only; it changes nothing in the skill.
2. **Read every diff in full.** Don't truncate the output or skim the summary line. If a diff is a whole-file reformat (bullet style, frontmatter appearing or vanishing), the fetch method flipped; compare the content, not the format.
3. For each changed page, update the reference file its manifest row names. Edit the chezmoi source (`~/.local/share/chezmoi/dot_claude/skills/writing-claude-prompts/`), never the deployed copy under `~/.claude/skills/`; the change goes live on `chezmoi apply`. Keep the file's shape: header with source URL and fetched date, symptom-to-fix table, verbatim snippets. Copy changed snippets word for word from the new scrape.
4. For each new page the recipe lists, scrape it (`firecrawl scrape <url> --only-main-content -o .firecrawl/<slug>.md`; fetch `<url>.md` instead if the result is backslash-escaped). If it's a model guide, write `references/<model>.md` and add a row to the "Which model, which quirks" table. Either way, add a manifest row to `references/sources.md`.
5. Bump the `Fetched:` date in each file you updated and the `Fetched` column in `references/sources.md` for every page re-fetched, changed or not.
6. Check the rest of `SKILL.md` (principles, legacy-scaffolding list, surfaces) against what changed.
7. **Never delete or weaken a field note because the docs now seem to say otherwise.** List the conflict for Alex with both sides quoted, and let him decide.
8. Report what changed in the *guidance*: which behaviors, defaults, or snippets moved, and what a prompt author should now do differently. A list of touched files is not a report.
