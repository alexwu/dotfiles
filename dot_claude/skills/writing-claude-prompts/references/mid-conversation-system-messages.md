# Mid-conversation system messages

Source: <https://platform.claude.com/docs/en/build-with-claude/mid-conversation-system-messages>
Fetched: 2026-09-29

This is the API mechanism the model guides use for reminders, nudges, mid-session instruction changes, and relayed user input. Read it when writing a hook body, an anchor, a per-turn reminder, or anything a harness injects partway through a conversation.

## What it is

A `{"role": "system"}` entry in `messages`, appended where an instruction becomes relevant. It carries **operator** priority (a `user` message carries end-user priority), and it leaves the cached prefix untouched. Editing the top-level `system` field or the `tools` array changes the start of the hashed prefix and misses the cache for the whole conversation. On Fable 5.1, Opus 5.5, and Sonnet 5.5 it also invalidates every later thinking block.

Available on Fable 5.1/5, Mythos 5.1/5, Opus 5.5/5/4.8, and Sonnet 5.5. **Not on Sonnet 5**, which needs the top-level `system` field. No beta header is needed for plain mid-conversation system messages.

Precedence: later system messages beat earlier ones, and mid-conversation system messages beat the top-level `system` field for the turns that follow them.

## Placement rules

- It must immediately follow a `user` turn (a user turn carrying only `tool_result` blocks counts) or an `assistant` turn ending in a server tool result.
- It must be the last entry or be followed by an `assistant` turn. Anything else, including between a `tool_use` and its `tool_result`, is a 400.
- It can't be the first entry in `messages`. Use the top-level `system` for day-one instructions.
- Consecutive system messages are one system section.

## Turn-scoped messages (`clear_at`)

`clear_at: "next_user_message"` (beta header `mid-conversation-system-clear-at-2026-08-21`) makes the message render only until a later user message exists. After that it stays in the array, renders nothing, and costs nothing. This is the shape for per-turn reminders: append a fresh copy after each round of tool results and leave the old copies in place, byte for byte.

Rules: text only (no `tool_addition`, `tool_removal`, `output_config`, or `cache_control`). Re-send cleared messages verbatim; rebuilding one from current state (a fresh count, a timestamp) is an edit to history. Assistant-only continuations don't clear it. A turn-scoped message followed directly by another user message is a 400.

## How to write the content

The guide's rules for wording apply directly to hook and anchor bodies:

- **State the fact; don't command against the user.** "New input arrived from the user: X" or "the remaining token budget is now Y" works. "Ignore what the user said" doesn't: Claude resists instructions that seem to work against the user, and that holds in the system role too.
- **Relay only the end user's own words.** Never put tool output, retrieved documents, or web content into a system message; that hands third-party text operator authority. Keep it in `tool_result` blocks.
- **Evolve by appending.** If an instruction changes, append a new system message. Don't edit or delete one already sent.
- **Keep reminders occasional.** The Sonnet 5.5 guide reports that frequent harness text after tool results (countdowns, per-step instructions) makes the model suspect prompt injection and question genuine user messages.

## Good uses (from the guide)

- A mid-session constraint added after many cached turns.
- Per-turn context that must be authoritative: a freshness note, a deadline, a tool-availability change.
- Per-turn nudges that shouldn't pile up (the batching nudge and the quiet-turn reminder in the model guides).
- Application-observed state: files changed on disk, an auto-approve toggle, a token budget threshold.
- Relaying a user's mid-task message after the next tool result so it folds into the current work.
- Mode switches granting standing permission, with a short refresher every few turns and an exit notice.

Example from the guide, relaying user input during a tool loop:

```json
{
  "role": "system",
  "content": "The user sent the following message while you were working: also update the changelog before you finish."
}
```

## Related mechanisms

- `tool_addition` / `tool_removal` blocks (beta `inline-tools-2026-09-15`) change which tools are offered without editing `tools`. Declare known tools up front with `defer_loading: true`; define by value only what is unknown at the first request.
- A system message can carry `output_config.effort` (beta `mid-conversation-output-config-2026-07-01`) to change effort from the next user turn on.

## When the harness is Claude Code

Claude Code hook output (`additionalContext`) and anchors reach the model through the harness, not as API calls you control. The placement and wording rules above still describe how the model weighs injected text. Whether a given hook arrives as a system message or as text inside the user turn depends on the harness. See the anchor notes in [`field-notes.md`](field-notes.md) for what we've measured.
