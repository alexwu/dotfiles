---
paths:
  - "dot_config/llama-swap/**"
  - "private_Library/LaunchAgents/com.github.mostlygeek.llama-swap.plist"
---

# LLM Local Inference

## llama-swap
- Config: `dot_config/llama-swap/config.yaml` — hot-reloads via `-watch-config` after `chezmoi apply`
- LaunchAgent plist changes need `launchctl unload/load` (not just chezmoi apply)
- LaunchAgent CWD is `/` (read-only on macOS SIP) — spawned processes need absolute paths for writable dirs
- Does NOT proxy WebSocket connections — connect directly to backend for realtime endpoints
- `setParamsByID` works for JSON body endpoints (`/v1/audio/speech`) but NOT multipart form endpoints (`/v1/audio/transcriptions`)
- `checkEndpoint` defaults to `/health` — override to `/v1/models` for mlx-audio entries
- Listens on `localhost:8000` (set in the LaunchAgent argv). OpenAI-compat endpoints live under `/v1/...`; llama-swap admin endpoints (`/running`, `/health`, `/logs`, `/upstream/:model_id`, `/metrics`) sit at the root.
- `~/.local/bin/llm-local` is the in-house wrapper for talking to it without going through codex/claude/gemini/pi CLIs — see `claude-scripts.md` for the binary, this file for the server-side facts.

## llama-swap management routes
Route table confirmed against `mostlygeek/llama-swap` `internal/server/server.go` + `api.go` (server v217, build 2026-05-22). Lifecycle-relevant subset:

| Method | Path | Effect |
|---|---|---|
| `GET` | `/unload` | unload **all** models (plain-text `OK`); legacy |
| `POST` | `/api/models/unload` | unload all (JSON `{"msg":"ok"}`); UI-facing |
| `POST` | `/api/models/unload/{model...}` | unload **one** model; name is a path segment (slashes OK), no body |
| `GET` | `/running` | list non-stopped processes (`{running:[{model,state,cmd,proxy,ttl,name,description}]}`) |
| `GET` | `/v1/models` | OpenAI model listing (all configured + peers) |
| `ANY` | `/upstream/{model}/{path...}` | pass-through to the model's own process; resolves the model from the path prefix, strips `/upstream/<model>` before forwarding |
| `GET` | `/health`, `/metrics`, `/api/version` | diagnostics (`/metrics` is Prometheus; `/api/version` → `{version,commit,build_date}`) |
| `GET` | `/logs`, `/logs/stream[/proxy\|/upstream\|/{model}]` | combined/streamed log tail (`?no-history` skips the backlog) |

- **No native load/preload route.** A model loads only on-demand (first inference request) or via config `hooks.on_startup.preload`. The runtime substitute is `GET /upstream/<model>/health` — proxying *any* request through `/upstream/<model>` forces the swap-in, and `/health` is the cheapest (no token generation, no chat-template). llama-swap holds the request open through the cold-load, so it doubles as a wait-until-ready barrier. This is exactly what `llm-local load` does.
- Unloading is **not destructive** beyond freeing the resident process — the model reloads on its next request. A default-group load (e.g. `Qwen3.5-9B`) won't evict `always-on` / `workhorse` / `code-completion` residents (group-pressure rules above), so it's safe to load a throwaway model alongside the working set.

## llama-swap groups
Three orthogonal group flags govern how models share VRAM (schema defaults `swap: true`, `exclusive: true`, `persistent: false`). A model can only be in one group; `groups` and `matrix` are mutually exclusive (this repo uses `groups`).

| flag | what it controls |
|---|---|
| `swap` | **intra-group**: `true` = one member runs at a time, `false` = all members run concurrently |
| `exclusive` | **outgoing pressure**: when a member loads, does it unload *other* groups? |
| `persistent` | **incoming protection**: can *other* groups unload these? |

- **`always-on`** (`persistent: true`, `swap: false`, `exclusive: false`) — resident helpers + hot-path models that run concurrently and can't be evicted. Members: `Qwen3.5-9B-MLX-4bit`, `Qwen3.6-35B-A3B-heretic` (dictation-cleanup hot path), `gemma-4-26B-A4B-it` (image-sort default classifier), `gemma-4-31B-it` (EXPERIMENT — moved from workhorse to gauge always-resident perf vs. unified-memory cost; swap:false holds all three big models at once).
- **`code-completion`** (`swap: true`, `exclusive: false`, `persistent: true`) — next-edit models, one resident at a time (you drive a single completion provider at a time). `persistent` keeps the active one sticky mid-edit; `exclusive: false` so it never disturbs always-on/workhorse. Members: `sweepai/sweep-next-edit-1.5b`, `henrik3/sweep-next-edit-v2-7B`, `zed-industries/zeta-2`, `zed-industries/zeta-2.1`. CAVEAT: running Zed (zeta) AND a Sweep-backed editor simultaneously thrashes (each load evicts the other) — flip to `swap: false` then.
- **`workhorse`** (`swap: true`, `exclusive: false`, `persistent: true`) — mid-tier models that hold the slot against default-group churn (one-off models can't evict them) but trade among themselves. Members: `Qwen3.6-27B`, `Qwen3.6-35B-A3B`, `Qwen3.6-27B-heretic`. Reserve the `heavy` group name for the true heavyweights (Mistral Medium 3.5 128B, Qwen3.5-122B-A10B) when those move out of the default group.
- (implicit default group) — every other model. Default flags, so they evict each other and are blocked from evicting `always-on` / `workhorse` members.
- TTL still applies as the idle-eviction backstop — `persistent` only blocks *other-group* unloads, not the model's own ttl timer.

## llama-swap structured output enforcement (CRITICAL for guard hooks)
Not every backend + endpoint combination actually enforces `json_schema strict: true`. Verified empirically 2026-05-28 against the truncation-guard schema (`~/.config/llm/schemas/strict/pretooluse.schema.json`):

| backend | endpoint | enforcement |
|---|---|---|
| `llama-server` | `/v1/chat/completions` + `response_format.json_schema.strict: true` | ✅ byte-perfect strict JSON |
| `llama-server` | `/v1/responses` + `text.format.json_schema` | ❌ accepted but **not** constrained |
| `llama-server` | `/v1/responses` + `response_format` (workaround) | ✅ works via bulk-copy passthrough, but brittle |
| `mlx_lm.server` / `mlx_vlm.server` | `/v1/chat/completions` + `response_format` | ❌ soft hint only — markdown fences, flattened wrapper keys |

**llama.cpp Responses-API gap details**: the converter at `tools/server/server-chat.cpp` extracts `input`, `instructions`, `tools`, `max_output_tokens` then `json chatcmpl_body = response_body` bulk-copies everything else. It never translates `text.format` → `response_format`. Downstream `oaicompat_chat_params_parse` reads structured output exclusively from `response_format.json_schema.schema` in `server-common.cpp`. No issue/PR tracks the gap as of 2026-05-28.

**Rule of thumb**: for any guard / classifier that depends on byte-exact JSON, route through `llama-server` (workhorse models) via `/v1/chat/completions` with `response_format`. The Responses-API `response_format` passthrough works but relies on implementation-detail behavior that will silently break the moment llama.cpp adds proper `text.format` translation.

## mlx-audio
- Installed via mise pipx: `"pipx:mlx-audio" = { version = "latest", extras = "all,server" }`
- Upstream `[all]` extras missing `python-multipart` — need both `all` AND `server` extras
- Venv needs `ensurepip` bootstrapped — Kokoro's spaCy downloads require `python -m pip`
- `mlx_audio.server --workers N` uses uvicorn multi-process mode which BREAKS WebSocket upgrades
- For WebSocket: run `python -m uvicorn mlx_audio.server:app` in single-process mode instead
- Voxtral Realtime does NOT support context/prompt conditioning — proper noun recognition is limited
