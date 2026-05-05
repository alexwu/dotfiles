---
name: using-pi
description: Send one-shot LLM prompts from the shell via the `pi` CLI — to local llama-swap models, OpenRouter, GitHub Copilot, or Anthropic direct. Use whenever you need a quick LLM call without spinning up another Claude/Codex session — second opinions, prompt-testing a system message, delegating cheap work to a local model, summarizing or transforming text, or scripting AI calls into a justfile / Nim / bash pipeline. Triggers on "ask pi", "use pi", "test this prompt against a model", "second opinion from another model", "delegate to local model", "send to OpenRouter", or any reference to the `pi` binary or `~/.pi/agent/`. Prefer this over spawning a subagent when you just need a single LLM round-trip.
---

# Using `pi`

`pi` is a coding-assistant CLI (binary at `~/.local/share/mise/installs/pi/<ver>/pi`, on PATH as `pi`). It speaks every major provider — local llama-swap, OpenRouter, Anthropic direct, OpenAI, GitHub Copilot, Cerebras, Groq, Bedrock, etc. — through one flag interface. Treat it as a Claude/Codex alternative for one-shot LLM calls from the shell.

This skill is about using `pi` as **inference-as-a-tool** — give it a prompt, get a reply, exit. For interactive agentic loops (file editing, multi-turn debugging) just run bare `pi` instead and let it use its own tools.

## When to reach for `pi`

- **Second opinions** — ask a different model to review a design before committing to it
- **Cheap delegation** — local Qwen 35B is fast and free; route grunt work there
- **System-prompt iteration** — test a prompt against a model without burning a Claude turn
- **Scripted AI** — embed inference in a justfile / Nim binary / bash pipeline

Skip `pi` and use a real subagent (`Agent`/`Task`) when you need parallel research with tools, or persistent context across calls.

## The lockdown invocation

Every one-shot call should pin these flags. They turn `pi` from a stateful agentic CLI into a pure inference function:

```bash
pi --print \
   --no-session \
   --no-context-files \
   --no-extensions \
   --no-skills \
   --no-prompt-templates \
   --no-tools \
   --provider <provider> \
   --model <model-id> \
   "<user prompt>"
```

| Flag | Why |
|------|-----|
| `--print` / `-p` | Non-interactive — process the prompt and exit. **Without this, `pi` opens a TUI and your script hangs.** Always pin. |
| `--no-session` | Don't write a session file to `~/.pi/agent/sessions/`. Ephemeral, no litter. |
| `--no-context-files` / `-nc` | Don't auto-load `AGENTS.md` / `CLAUDE.md` from cwd. Critical when calling from inside another agent's session — those files are about that agent, not this prompt. |
| `--no-extensions` / `-ne` | Skip extension discovery. Predictable behavior. |
| `--no-skills` / `-ns` | Skip `pi`'s own skill discovery. |
| `--no-prompt-templates` / `-np` | Skip prompt-template discovery. |
| `--no-tools` / `-nt` | Disable read/bash/edit/write/grep/find/ls. **Pure inference, no side effects.** Drop this if you actually want the model to read files (use `--tools read,grep,find,ls` for read-only delegation). |

Memorize the shape, not the literal string. The lockdown is the contract: *one prompt in, one reply out, no surprises.*

## Providers & recommended models

`pi` providers configured locally (per `~/.local/share/chezmoi/dot_pi/agent/private_models.json` and built-ins):

### `llama-swap` — local inference (free, fast, private)

Base URL: `http://127.0.0.1:8000/v1`. Models swap on-demand via the launchctl-managed daemon.

| Model id | When to use |
|----------|-------------|
| `Qwen3.6-35B-A3B` | **Default local pick.** MoE, ~3B active params, fast. Good for summarization, refactor reviews, classification. |
| `Qwen3.6-35B-A3B:thinking` | Same model with reasoning enabled. Slower. Use for harder reasoning tasks. |
| `Qwen3.5-122B-A10B` | Largest local model. ~10B active. Slower swap. Reach for it when 35B isn't smart enough. |
| `Qwen3.6-27B` (+`:thinking`) | Dense 27B, vision-capable. Use when you have an image to feed in. |
| `Qwen3.5-9B` (+`:thinking`) | Tiny + fast. Cheap classification, regex-y tasks. |
| `mlx-community/Qwen3.5-9B-4bit` | Always-on MLX, lowest latency for trivial calls. |

### `openrouter` — frontier models, paid

Auth via `OPENROUTER_API_KEY` env var. Anything OpenRouter exposes is callable. Common picks:

| Model id | When to use |
|----------|-------------|
| `anthropic/claude-opus-4.7` | Heaviest Claude. Reach for it for genuinely hard reasoning. |
| `anthropic/claude-sonnet-4.6` | Cheaper Claude, still strong. Default frontier pick for most second opinions. |
| `anthropic/claude-haiku-4.5` | Fast + cheap Claude. Good for classification or short rewrites. |
| `google/gemini-3.1-pro-preview` | Long-context tasks, Google reasoning patterns. |
| `deepseek/deepseek-v3.2` | Cheap, strong on code. |
| `moonshotai/kimi-k2.5` | Long-context, agentic-leaning. |

### `anthropic` — direct, no proxy fee

Auth via `ANTHROPIC_API_KEY` or `ANTHROPIC_OAUTH_TOKEN`. Same Claude models as OpenRouter, just no middleman. Prefer this over OpenRouter when both work and you have the credential.

### `github-copilot` — gpt-5.x via Copilot subscription

Already wired (`defaultProvider` in `~/.pi/agent/settings.json`). `gpt-5.1` and friends. Use when Copilot quota is what you have.

### Other built-ins

`openai`, `google` (Gemini direct), `groq`, `cerebras`, `xai`, `deepseek`, `bedrock`, `mistral`, etc. All listed in `pi --help` under "Environment Variables". Same flag interface — `--provider <name> --model <id>`.

## Recipes

### Quick local one-shot

```bash
pi --print --no-session --no-context-files --no-extensions \
   --no-skills --no-prompt-templates --no-tools \
   --provider llama-swap --model Qwen3.6-35B-A3B \
   "Summarize this commit message in one sentence: feat(auth): add JWT-based session refresh"
```

### Frontier second opinion via OpenRouter

```bash
pi --print --no-session --no-context-files --no-extensions \
   --no-skills --no-prompt-templates --no-tools \
   --provider openrouter --model anthropic/claude-opus-4.7 \
   --thinking high \
   "Review this migration plan for race conditions: $(cat plan.md)"
```

### System prompt + user prompt (the justfile `test` pattern)

```bash
pi --print --no-session --no-context-files --no-extensions \
   --no-skills --no-prompt-templates --no-tools \
   --provider openrouter --model anthropic/claude-opus-4.7 \
   --system-prompt "$(cat Prompts/Agents/CLAUDE_CODE.md)" \
   "your test prompt here"
```

The `--system-prompt` flag takes literal text. To load a file, either `$(cat path)` it in shell, or use `--append-system-prompt` (which accepts both literals and file contents — repeatable for layering).

### Attach files to the user message

`pi`'s positional `@file` syntax inlines file contents (and images) into the user message:

```bash
pi --print --no-session --no-context-files --no-extensions \
   --no-skills --no-prompt-templates --no-tools \
   --provider llama-swap --model Qwen3.6-27B \
   @screenshot.png "What's wrong with this UI?"
```

Multiple files allowed: `pi @a.py @b.py "compare"`.

### Read-only delegation (file analysis without write access)

If you want the model to *read* files but not modify them, swap `--no-tools` for an explicit allowlist:

```bash
pi --print --no-session --no-context-files --no-extensions \
   --no-skills --no-prompt-templates \
   --tools read,grep,find,ls \
   --provider llama-swap --model Qwen3.6-35B-A3B \
   "Find every place that calls authenticate() in src/ and tell me which ones skip rate-limiting"
```

### Pick the response format

`--mode json` returns structured JSON output instead of plain text. Useful when piping into `jaq`/Nim/bash:

```bash
pi --print --mode json --no-session --no-context-files --no-extensions \
   --no-skills --no-prompt-templates --no-tools \
   --provider llama-swap --model Qwen3.5-9B \
   "Classify this commit type. Reply only with one of: feat, fix, chore, refactor, docs, test"
```

### Thinking levels

`--thinking <level>` where level is `off | minimal | low | medium | high | xhigh`. Default for openrouter is medium per `~/.pi/agent/settings.json`. For local models, thinking is opt-in via the `:thinking` model suffix (`Qwen3.6-35B-A3B:thinking`) — the `--thinking` flag also works on providers that support it.

## Pitfalls

- **Don't omit `--print`.** Without it, `pi` opens an interactive TUI and the call hangs. Every scripted invocation needs `-p`.
- **Don't omit `--no-context-files`** when calling from inside an agent session. Without it, `pi` will pick up the current project's `CLAUDE.md` / `AGENTS.md` and contaminate the inference with off-topic instructions. The justfile pattern includes it for a reason.
- **`--no-session` and `--no-tools` together = pure function call.** Drop either one and you're back in agentic territory.
- **The lockdown is per-call, not a settings change.** The flags don't persist; you have to pass them every invocation. (You *can* edit `~/.pi/agent/settings.json` for global defaults like provider/model/thinking, but not for the no-tools flags.)
- **Local models have warm-up latency.** First call to a cold model swaps it in (10–60s). Subsequent calls are instant until the `ttl` expires. If you're benchmarking, throw away the first call.
- **Quote your prompts.** Single-quote when there are double-quotes in the prompt; heredoc when there are both. Shell quoting bugs cause the most "why is `pi` ignoring me" moments.
- **`pi`'s exit code is nonzero on inference errors** (auth, network, model unavailable). Check `$?` in scripts before parsing the output.
- **Streaming output goes to stdout; status/progress to stderr.** Redirect `2>/dev/null` if you only want the model's reply.

## When NOT to use `pi`

- **You need a real agent loop with tools across multiple turns** — for that, the right tools are:
  - `codex` — already installed as a Claude Code plugin (see `codex:codex-rescue` agent and `/codex:rescue` skill). Reach for this when you want a separate stateful coding agent to take over a problem.
  - `gemini` CLI — covered by a sibling skill (`using-gemini`). Use it when you want Gemini's agentic loop specifically.
  - A bare interactive `pi` session (drop `--print`) — your own agentic loop in `pi`.
  - A Claude Code subagent (`Agent`/`Task`) — when the work fits inside this session and just needs isolation/parallelism.
- **You need streaming output rendered in a UI** — `pi --print` buffers; for streaming use `--mode rpc` or interactive.
- **The task needs the calling agent's full context** — `pi` is a clean room. If you need this session's history, you can't get it through `pi`.
- **You need parallel research across many sources** — that's what subagents are for. `pi` is single-shot.

## Quick reference card

```
ALWAYS: --print --no-session --no-context-files --no-extensions \
        --no-skills --no-prompt-templates --no-tools

LOCAL:    --provider llama-swap --model Qwen3.6-35B-A3B
FRONTIER: --provider openrouter --model anthropic/claude-sonnet-4.6
HARD:     --provider openrouter --model anthropic/claude-opus-4.7 --thinking high
TINY:     --provider llama-swap --model Qwen3.5-9B

FILES:    pi @path/to/file.ext @another.png "prompt about them"
SYSPROMPT: --system-prompt "$(cat path/to/prompt.md)"
JSON OUT: --mode json
```
