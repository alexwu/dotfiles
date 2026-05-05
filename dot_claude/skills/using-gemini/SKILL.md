---
name: using-gemini
description: Drive Google's `gemini` CLI from the shell — both as a headless one-shot inference tool and as a full agentic coding loop with worktrees, sandboxes, approval modes, and sessions. Use whenever you need a Gemini-specific call (long context, image understanding, Google's reasoning patterns), want a separate stateful coding agent to take over a task, or need a sandboxed/worktree-isolated experiment. Triggers on "ask gemini", "use gemini", "run gemini", "gemini-3", "second opinion from Gemini", "long-context analysis", "Google AI", "let gemini-cli do this", "yolo this", "spin up a gemini worktree", or any reference to the `gemini` binary or `~/.gemini/`. Prefer this over `pi` when you specifically want a Google model; prefer it over a Claude Code subagent when you want an actual separate agent to keep working in another session.
---

# Using `gemini`

`gemini` is Google's official Gemini CLI (binary at `/opt/homebrew/bin/gemini`). It's a full coding agent in its own right — defaults to interactive, has its own skills/extensions/hooks/MCP ecosystem, supports git worktrees and sandboxing natively. Auth is OAuth-personal (your `~/.gemini/oauth_creds.json`) or `GEMINI_API_KEY`.

This skill covers two distinct modes — pick based on what you're using `gemini` *for*:

- **Headless one-shot** (`gemini -p "..."`) — inference-as-a-tool. Same shape as the `using-pi` skill, just constrained to Google models. Reach for this when you want Gemini's reasoning specifically (long context, multimodal, Google's distinctive style) for a single round-trip.
- **Agentic loop** (`gemini` interactive, with approval modes) — let `gemini` actually do the work. This is where it differs from `pi`. Reach for this when you want a separate, stateful coding agent to take over a problem in another window/worktree while you keep working here.

## When to reach for `gemini` (vs alternatives)

| Need | Tool |
|------|------|
| Cheap one-shot LLM call, any provider | `pi` (see `using-pi` skill) |
| Gemini-specific one-shot (long context, image, Google reasoning) | `gemini -p` |
| Separate stateful coding agent to take over | `gemini` interactive — or `codex` (see `codex:codex-rescue`) |
| Read-only code review by another agent | `gemini --approval-mode plan` |
| Sandboxed experiment that might write files | `gemini --sandbox --worktree <name>` |
| Parallel research inside this Claude Code session | `Agent`/`Task` subagent — not `gemini` |

## Mode 1 — Headless one-shot

The lockdown for inference-as-a-tool. **`gemini`'s lockdown surface is smaller than `pi`'s** — there's no clean `--no-tools`/`--no-skills`/`--no-context-files` triple. The closest you can get:

```bash
gemini --prompt "<user prompt>" \
       --model gemini-3-flash-preview \
       --output-format text \
       --approval-mode plan
```

| Flag | Why |
|------|-----|
| `-p` / `--prompt "<text>"` | Non-interactive headless mode. **Without this, `gemini` opens a TUI and your script hangs.** Always pin. (Stdin is appended if you also pipe content in.) |
| `-m` / `--model <id>` | Pin a specific model — don't rely on defaults. See "Models" below. |
| `-o text` / `--output-format` | Plain text. Use `json` or `stream-json` for structured/streaming. |
| `--approval-mode plan` | Read-only mode. The closest equivalent to `pi`'s `--no-tools` — tools can still be called but only for reads. Skip it if you need writes; it's still safer than `default` for inference work. |

Caveats unique to `gemini`:

- **No clean `--no-skills` / `--no-extensions` toggle.** Skills from `~/.agents/skills/` and `~/.gemini/skills/` auto-discover and may trigger. If a skill causes drift, either move it out or use `-e <only-the-extensions-you-want>` to pin a subset (no equivalent for skills currently).
- **`GEMINI.md` is auto-loaded** from cwd / project / `~/.gemini/GEMINI.md`. There's no `--no-context-files` flag. If you're calling `gemini` from inside a project, expect that file to influence the response. Run from `/tmp` if you need a clean room.
- **Sessions are saved by default.** Headless calls still leave artifacts under `~/.gemini/`. Use `gemini --list-sessions` and `--delete-session <idx>` to clean up periodically — or accept the noise.

## Mode 2 — Agentic loop (the real differentiator)

When you want `gemini` to actually do work — read code, edit files, run commands, iterate — drop `--prompt` and let it run interactively, or invoke it as a separate agent in another terminal/worktree while you keep working here.

### Approval modes

`--approval-mode <mode>` controls how aggressively `gemini` acts:

| Mode | Behavior | Use when |
|------|----------|----------|
| `default` | Prompts before every tool call | Cautious manual review of each step |
| `auto_edit` | Auto-approves edit tools, prompts for shell/etc. | You trust file edits but want to vet shell commands |
| `yolo` (or `-y` / `--yolo`) | Auto-approves everything | Sandboxed/worktree work where blast radius is bounded |
| `plan` | Read-only — no writes possible | Code review, analysis, exploration without risk |

Pair `yolo` with `--sandbox` and/or `--worktree` to bound the blast radius. Bare `-y` in your live cwd is *spicy*.

### Worktree isolation

```bash
gemini --worktree feat-new-thing --approval-mode yolo \
       "implement the new caching layer for the storage service"
```

`--worktree [name]` spins up a git worktree (auto-named if you omit the name) and runs there. Pairs naturally with `yolo` since the work is isolated to the worktree — bad outcomes don't pollute your main checkout.

### Sandbox mode

`-s` / `--sandbox` runs the agent inside a sandbox. Combine with `--yolo` if you want full autonomy without filesystem risk.

### Sessions & resume

```bash
gemini --list-sessions             # see what's saved
gemini --resume latest             # pick up where you left off
gemini --resume 3                  # specific session by index
gemini --delete-session 5          # clean up old ones
```

### Extending the workspace

```bash
gemini --include-directories ~/Code/lulu-app,~/Code/lib-shared "trace the auth flow across both repos"
```

Adds extra directories to the agent's workspace beyond cwd. Useful when work spans multiple repos.

### Policy & MCP

- `--policy <file>` / `--admin-policy <file>` — fine-grained tool control via the Policy Engine (replaces the deprecated `--allowed-tools`)
- `--allowed-mcp-server-names <a,b,c>` — restrict which MCP servers the agent can talk to
- `gemini mcp` subcommand — manage MCP server registrations

### Migrating Claude Code hooks

```bash
gemini hooks migrate
```

Converts your Claude Code hook config into Gemini's hook format. Worth running once if you've invested in hooks under `~/.claude/`.

### Local Gemma routing

```bash
gemini gemma --help    # configure local Gemma model routing
```

Gemini CLI has a built-in path to route to local Gemma models — analogous to `pi`'s `llama-swap` provider, but Google-only and Gemma-specific.

## Models

Current Gemini 3.x family (May 2026):

| Model id | Size | When to use |
|----------|------|-------------|
| `gemini-3.1-flash-lite-preview` | Tiny | Cheapest/fastest. Classification, short rewrites, scripting. Reach for it when latency/cost matters more than quality. |
| `gemini-3-flash-preview` | Medium | Balanced. **Default headless pick.** Most second-opinion / summarization / agentic work lives here. |
| `gemini-3.1-pro-preview` | Large | Frontier reasoning. Long-context analysis, hard code review. Expensive — reach for it deliberately. |

Model IDs change as Google ships new releases. If `-m <id>` errors, run `gemini -p "hi" -m <bogus>` to get an error listing valid IDs, or check the [Gemini API docs](https://ai.google.dev/gemini-api/docs/models). Update this table when picks shift.

## Recipes

### Quick second opinion

```bash
gemini -p "Review this design for race conditions: $(cat plan.md)" \
       -m gemini-3.1-pro-preview \
       -o text \
       --approval-mode plan
```

### Pipe code in via stdin (no system prompt needed; just attach)

```bash
cat src/auth.py | gemini -p "find every place that skips rate-limiting and explain the risk" \
                         -m gemini-3-flash-preview \
                         --approval-mode plan
```

### Long-context multi-file review

```bash
gemini --include-directories ~/Code/lulu-app/src,~/Code/lulu-app/tests \
       -p "audit the test coverage of the auth module — list functions with no tests" \
       -m gemini-3.1-pro-preview \
       --approval-mode plan
```

### Hand off a coding task to a sandboxed worktree

```bash
gemini --worktree refactor-cache --sandbox --yolo \
       -m gemini-3.1-pro-preview \
       "Refactor the caching layer to use Redis. Update tests. Commit when green."
```

Spawns the agent in a fresh worktree under a sandbox with full autonomy. Walk away; come back to a branch with the work done (or an explanation of what blocked it).

### Resume a previous agentic session

```bash
gemini --list-sessions
gemini --resume latest
```

### Structured JSON output (for scripting)

```bash
gemini -p "Classify this commit type. Reply only with one of: feat, fix, chore, refactor, docs, test. Subject: $(git log -1 --format=%s)" \
       -m gemini-3.1-flash-lite-preview \
       -o json \
       --approval-mode plan
```

`stream-json` is also available if you want to consume tokens as they arrive.

## Pitfalls

- **Don't omit `-p`/`--prompt`.** Without it, `gemini` opens a TUI and a scripted call hangs forever. Same trap as `pi`.
- **`GEMINI.md` will leak in.** Unlike `pi --no-context-files`, there's no flag to skip context files. If a stale `GEMINI.md` is contaminating responses, run from `/tmp` or move the file aside temporarily.
- **Skills auto-discover.** Anything in `~/.agents/skills/` or `~/.gemini/skills/` is potentially loaded. There's no `--no-skills`. If a skill is interfering, you'll need to disable it at the source.
- **Sessions accumulate.** Even headless calls write session files. Periodically run `gemini --list-sessions` and prune with `--delete-session <idx>`.
- **`-y` / `--yolo` is dangerous outside sandboxes/worktrees.** It auto-approves *everything*, including destructive shell commands. Always combine with `--sandbox` or `--worktree` unless you genuinely want unbounded autonomy in your cwd.
- **`--raw-output` is a security risk.** It allows ANSI escape sequences in output. Don't use it unless you have a specific reason and trust the model's output stream.
- **Auth: OAuth-personal vs API key have different rate limits.** OAuth-personal (the default in `~/.gemini/settings.json`) is gated by Google's per-account quota; `GEMINI_API_KEY` is paid-per-token via Google AI Studio. They're not interchangeable for high-throughput scripting.
- **Stdin is *appended* to the prompt, not replaced.** `cat foo | gemini -p "bar"` sends `bar\n<contents of foo>` to the model. Useful for the "system intent + data payload" pattern.
- **Trust prompts on first run in a new directory.** `gemini` prompts you to trust each new workspace. `--skip-trust` bypasses for one session; permanent trust lives in `~/.gemini/trustedFolders.json`.

## When NOT to use `gemini`

- **You want a non-Google model.** Use `pi` (`using-pi` skill). `pi` covers Anthropic, OpenAI, OpenRouter, local llama-swap, etc.
- **You want a separate Claude/OpenAI agent loop.** Use the `codex` plugin (`codex:codex-rescue`) for an OpenAI-Codex agent, or invoke a Claude Code subagent (`Agent`/`Task`) for parallel work in *this* session.
- **You need cheap local-only inference.** `pi --provider llama-swap` is faster and free for grunt work. `gemini gemma` exists but is narrower.
- **You need streaming output rendered in a UI from headless mode.** Use `-o stream-json` and consume the stream — but most UIs assume interactive `gemini` for streaming.
- **You're inside a Claude Code session and just need a one-shot LLM call to Gemini.** `pi --provider openrouter --model google/gemini-3.1-pro-preview` is simpler than spinning up a separate `gemini` invocation. Use `gemini -p` only when you specifically want gemini-cli's behavior (extensions, skills, GEMINI.md context).

## Quick reference card

```
HEADLESS LOCKDOWN:
  gemini -p "<prompt>" -m gemini-3-flash-preview -o text --approval-mode plan

MODELS (May 2026):
  DEFAULT:  gemini-3-flash-preview          # mid, balanced
  TINY:     gemini-3.1-flash-lite-preview   # cheapest
  FRONTIER: gemini-3.1-pro-preview          # hard reasoning

AGENTIC:
  Plan-only:   gemini --approval-mode plan
  Auto-edit:   gemini --approval-mode auto_edit
  Yolo:        gemini -y --sandbox --worktree <name>

SESSIONS:    --list-sessions / --resume {latest|N} / --delete-session N
WORKSPACE:   --include-directories a,b,c
EXTRA REPO:  --worktree [name]
SAFETY:      --sandbox / --approval-mode plan
HOOKS:       gemini hooks migrate    # convert from Claude Code
LOCAL:       gemini gemma            # route to local Gemma
MCP:         gemini mcp              # manage MCP servers
```
