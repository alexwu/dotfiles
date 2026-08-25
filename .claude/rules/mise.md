---
paths:
  - "mise-config.toml"
---

# mise

## mise
- Config: `mise-config.toml` (symlink target — edits are live, no `chezmoi apply`)
- `[bootstrap.macos.launchd.agents.*]` — mise-managed LaunchAgents (llama-swap, caddy-tailscale), labels `dev.mise.<name>`. Converge with `mise bootstrap macos launchd-agents apply --yes` (rewrites plist, reloads, kickstarts); inspect with `… status --json`. Deleting an agent from the TOML does NOT prune the loaded job — manual `launchctl bootout` + rm.
- `settings.pipx.uvx = true` — pipx tools use uvx
- `settings.npm.bun = true` — npm tools use bun
- `settings.python.uv_venv_auto = true` — auto-create venvs with uv
- Rust toolchain: `nightly`
- Key tools: ruby, uv, bun, zig, rust, go, ruff, usage, cargo-binstall, petname, qsv, firecrawl-cli, playwright
