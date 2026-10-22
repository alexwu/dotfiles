# Chezmoi Dotfiles

Reference docs for this repo are split across `.claude/rules/`:

| File | Covers |
|------|--------|
| `chezmoi.md` | File naming, deployment commands, symlink targets, external repos, config registry |
| `llm-local.md` | llama-swap config + groups (hot-path / workhorse), structured-output enforcement gaps (MLX, `/v1/responses`), mlx-audio |
| `shell.md` | zsh/Zim, Atuin, FZF, Television, Just, 1Password |
| `mise.md` | mise config, tool backends, Rust toolchain, tool list |
| `git.md` | Git config (delta/difft/signing/LFS), Lazygit |
| `desktop.md` | AeroSpace, JankyBorders, Sketchybar, Hammerspoon, Yazi |
| `terminals.md` | Ghostty, WezTerm, Kitty, sessions on bmx/zmx (zn, zmx-* tools, session-shell chain), Zellij, Petname (DBZ) |
| `editors.md` | Neovim (both configs), Neovide |
| `hazel.md` | scripts/hazel/ tools (heic-ai-rename, image-sort, gif-mosaic), Hazel PATH gotcha |
| `macos.md` | scripts/macos/ tools (electron-apps), Electron detection signals, Homebrew cask layout |
| `caddy.md` | caddy-tailscale custom build, the llama-swap tailnet node, Caddyfile/plist/fnox wiring |

Coding-agent skills, subagents, slash commands, hook binaries, agent CLIs, and guard prompts live in `~/Code/lulu-loadout`, which deploys them with `just install`. This repo keeps the settings that point at them: `claude-settings.json` and `codex-config.toml`.
