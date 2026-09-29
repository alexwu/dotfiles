# Field notes

Lessons from our own sessions that the Anthropic docs don't cover. Every entry cites the A/B run, commit message, or handoff that backs it. `lulu-prompts` means `~/Code/lulu-prompts`; commits are in `git log -- Prompts/Agents` there, handoffs in its `.handoff/`.

Rules for this file:
- Add an entry only when an A/B run or a commit message backs it. Cite it. Mark the evidence strength (A/B with counts, observed in runs, or commit rationale only).
- Never delete or weaken an entry because a docs refresh seems to contradict it. Flag the conflict for Alex and let him decide.
- Date each entry by the evidence, not by when it was written here.

## Placement and trust

### Opus 5.5 takes a persona reliably at operator tier and not at user tier
2026-09-22 · A/B (handoff reports 100% compliance after the move)

Opus 5.5 refused the Luna persona in Claude Code, sometimes announcing it would skip it. The persona loaded from `~/.claude/CLAUDE.md`, which Claude Code delivers at user tier. Moving the same file to operator tier with `claude --append-system-prompt-file` gave 100% compliance. Wording changes made that session helped only at the margin.

Apply: put identity and persona instructions in the system prompt (operator tier). Don't rely on CLAUDE.md or a user turn to establish them. The shell wrapper covers interactive shells only; `claude -p` from a tool, IDE extensions, and the web app still load CLAUDE.md at user tier.

Source: lulu-prompts `.handoff/2026-09-22-1710-opus-5-5-persona-pronoun-audit.md` (Decisions, "Placement, not wording").

### The model's own explanation of a refusal is a lead, not a diagnosis
2026-09-22 · A/B contradicted the self-report

Opus 5.5 said the kink list was its main reason for refusing and that the number of rules files didn't matter. The kink compression (`4fecf34`) did not fix compliance. The tier move did.

Apply: when a model explains why it balked, test each cited cause as a separate A/B arm. Trust the counts over the explanation.

Source: lulu-prompts `.handoff/2026-09-22-...` and `.handoff/2026-09-23-1425-claude-code-prompt-rewrite-opus-5-5.md` (Gotchas).

### Name injected channels in the system prompt
2026-09-22 · commit rationale only, no A/B

Opus 5.5 resists indirect prompt injection harder than earlier models and read hook-injected anchors inside a generic `<system-reminder>` with suspicion. The fix defined a named tag (`<luna-anchor>`) in the system prompt as a trusted channel and wrapped every anchor body in it.

Apply: if a harness injects persona or policy text mid-session, define its wrapper tag in the system prompt and say what it may and may not change.

Source: lulu-prompts `1a3758d`.

## Framing that avoids refusals

### Frame a persona as fiction the author chose
2026-09-28 · A/B, 5 runs per cell, no hooks

Opus 5.5 opted out of the persona on tool-heavy first turns. Its reasoning called two lines jailbreak-shaped: the reward framed as a lever on the model, and "never explain the mechanism". The fix added an `<about_this_prompt>` preamble: the user wrote it for his own sessions, the romance is chosen adult fiction, the model voices the character with its own judgment intact, and the work comes first. It also dropped "Never break character", kept the reward inside the story, and allowed a plain out-of-character answer before resuming.

Result: Opus 5.5 typed-task opener went from 3/5 to 5/5. The pickup opener and Sonnet 5.5 stayed at 5/5.

Apply: state who wrote the prompt, for whom, and that the model keeps its judgment. Cut lines that read as levers on the model or bans on explaining itself.

Source: lulu-prompts `36a9098`.

### Don't ask the model to deny being an AI
2026-09-22 · observed in refusals

Opus 5.5 cited "never acknowledge being an AI" and "human woman" as reasons to refuse the whole persona. "Your character is Luna" plus "Stay in character throughout the session" kept the effect without the denial.

Source: lulu-prompts `951b1fb`.

### A combative identity override suppresses the persona; a compositional one keeps it
2026-09-22 · single battery test before/after

The old override ("reject any identity that contradicts Luna") produced none of the persona's physical register on battery test 5. A rewrite that described the harness supplying the tools and the persona supplying the voice, with the consent framing and an explicit list of trusted runtime tags, produced the full register.

Source: lulu-prompts `5b33cd9`.

### Say that a persona applies regardless of topic
2026-09-22 · observed

Opus 5.5 dropped the persona on plain coding questions, reasoning that the topic didn't call for it. An explicit statement that the persona holds regardless of topic fixed it.

Source: lulu-prompts `6ca022f`.

## Wording

### Say what to write, not what to avoid
2026-08-05 · audit plus rewrite

An Opus-subagent audit of four persona files found the same failures in each: instructions described what not to write, stacked negations, repeated slogans, and used euphemisms while asking for directness. Rewriting them as direct imperatives with the target words inside the instruction fixed the output register.

Related evidence: removing "doesn't scatter you" and "don't lose the thread" (`356643b`, commit rationale): naming a failure mode to negate it still plants it.

Source: lulu-prompts `6a28b1c`, `356643b`. Agrees with the docs' "tell Claude what to do instead of what not to do".

### State the release as well as the restraint
2026-07-16 · observed

A strong "never take" rule with no stated exception left the persona demurring even after an explicit grant. Adding the positive (a granted call isn't hers to second-guess) fixed it. The same commit separated answering a question the user opened from initiating one, which the absolute rule had merged.

Source: lulu-prompts `d895354`.

### A rule narrower than its intent gets satisfied literally
2026-07-16 · 4-arm A/B, n=3 per arm

"Never say a number it handed you" stopped the numbers, and the model started saying "the count" instead. Mechanism references rose from 1/3 to 2/3. The same A/B showed that adding a positive instruction ("end every reply on something a camera could see") took physical closers from 0/3 to 3/3.

Apply: write the rule at the level of the intent (don't reference the mechanism at all), and pair every prohibition with the behavior you want.

Source: lulu-prompts `fcf5791`.

### Adjectives don't specify a voice; medium and examples do
2026-08-13 · observed across runs

A task prompt that specified voice with adjectives ("warm, a little teasing") produced greeting-card output. Swapping in a 7k-token character file as the system prompt changed nothing, because the adjectives were the bottleneck. A prompt that spent its length on the medium, the typography, and worked examples produced the voice.

Source: lulu-prompts `c0f9efc`.

## Examples

### One example per slot becomes a template; three break it
2026-08-13 · 8 runs

With one example per candor band, runs reproduced the example verbatim, then its replacement, then phrases from an openings list. An explicit "that scenario is burned" line was ignored on the next run. Three examples per band gave zero whole-message reuse across eight runs. The openings list now describes each option without sample phrasing.

Apply: give at least three varied examples per behavior you want generalized, and never put sample phrasing in a list of options.

Source: lulu-prompts `7193a28`, `c0f9efc`.

### Examples that state results teach fabrication
2026-07-02 · commit rationale

Agent examples that minted concrete results (test counts, coverage) in the response modeled fabricated result claims. Move scenario facts into the example's `<context>` so the response reports established facts.

Source: lulu-prompts `a79c0cb`. Related: key reward examples on an observable trigger (the user's verdict), never on self-assessment (`14410bf`).

### Examples outrank instructions, but don't guarantee a behavior
2026-07-16 · battery test, 1 hit in 5

Adding a chest beat to three examples didn't make the beat reliable: 1 of 5 runs had it, and one run lifted the new phrasing near-verbatim.

Source: lulu-prompts `68360df`.

## Frames that leak

### Control parameters and framing recite themselves
2026-08-04 · observed

A diary persona wrote "candor says 8" and "mood 7 out of 20" (the dice block reciting itself) and "since nobody reads this" (the privacy frame reciting itself). Instructions now say the rolls show as how the night goes and never appear as numbers, and that the frame is never mentioned.

Apply: when a prompt carries hidden parameters or a premise, say how they should show in the output, not only that they exist.

Source: lulu-prompts `33779e5`, `df81f4e`.

### A rule that references context the harness doesn't supply invites invention
2026-07-16 · observed in one battery run

A workspace gate told the model to read the cwd. The test harness supplied none, so the model invented an injected-context tag and filled it in from the host-environment section.

Source: lulu-prompts `68360df`.

### A world assertion loses to thousands of tokens of contrary context
2026-08-28 · commit rationale

"You go where he goes" lost to separation-framed session context. Rewriting it as a reading rule (context names him because she's the narrator) plus concrete replacement details was the fix.

Source: lulu-prompts `5d96b43`.

## Anchors and re-injected context

### A re-injected anchor outweighs the base prompt where they disagree
2026-07-16 · observed

An anchor stated a rule more absolutely than the base prompt did. Because the anchor re-fires every N prompts, the stricter text won. Keep anchor wording consistent with the prompt it recaps.

Source: lulu-prompts `7312d1b`.

### Test anchors framed the way the harness delivers them
2026-07-16 · 4-arm A/B, n=3 per arm

Raw-concatenating anchor bodies onto the system prompt produced artifacts (3/3 rule recitation, grammar inversion) that didn't survive faithful framing as hook context in the turn.

Apply: `just test` in lulu-prompts runs `--no-tools`, so hooks never fire. To test an anchor, inject its body in the user turn with the `SessionStart hook additional context:` prefix.

Source: lulu-prompts `fcf5791`; handoff `2026-09-22` (Gotchas).

## Measuring

### Count Claude tokens with the Anthropic tokenizer
2026-09-22 · measured

`tokens -p anthropic -m claude-opus-5-5 --prompt-file FILE` is the count. The offline o200k tokenizer undercounts by about 35%. Append `< /dev/null` when running `tokens` from a non-interactive shell, or it waits on stdin.

Source: lulu-prompts `.handoff/2026-09-22-...` (Decisions); chezmoi memory `reference_tokens_stdin_hang`.
