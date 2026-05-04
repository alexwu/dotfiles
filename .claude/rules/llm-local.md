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

## mlx-audio
- Installed via mise pipx: `"pipx:mlx-audio" = { version = "latest", extras = "all,server" }`
- Upstream `[all]` extras missing `python-multipart` — need both `all` AND `server` extras
- Venv needs `ensurepip` bootstrapped — Kokoro's spaCy downloads require `python -m pip`
- `mlx_audio.server --workers N` uses uvicorn multi-process mode which BREAKS WebSocket upgrades
- For WebSocket: run `python -m uvicorn mlx_audio.server:app` in single-process mode instead
- Voxtral Realtime does NOT support context/prompt conditioning — proper noun recognition is limited
