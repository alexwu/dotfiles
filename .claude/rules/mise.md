---
paths:
  - "mise-config.toml"
---

# mise

## mise
- Config: `mise-config.toml` (symlink target — edits are live, no `chezmoi apply`)
- `settings.pipx.uvx = true` — pipx tools use uvx
- `settings.npm.bun = true` — npm tools use bun
- `settings.python.uv_venv_auto = true` — auto-create venvs with uv
- Rust toolchain: `nightly`
- Key tools: ruby, uv, bun, zig, rust, go, ruff, usage, cargo-binstall, petname, qsv, firecrawl-cli, playwright
