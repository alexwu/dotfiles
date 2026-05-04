---
paths:
  - "dot_zshrc"
  - "private_dot_zimrc"
  - "dot_zprofile"
  - "dot_zsh/**"
  - "dot_config/atuin/**"
  - "dot_config/television/**"
  - "dot_config/just/**"
---

# Shell

## Shell (zsh)
- Framework: **Zim** (`private_dot_zimrc`) — handles modules, compinit, completions
- Prompt: **Powerlevel10k** (default), **Starship** in Warp terminal (`dot_config/starship.toml`)
- Key plugins: fzf-tab, fast-syntax-highlighting, zsh-autosuggestions, zsh-completions
- `dot_zshrc` sources `dot_zsh/macos.zsh` on Darwin — sets up Homebrew, mise, 1Password SSH agent, LS_COLORS via `vivid generate snazzy`
- Shell aliases: `dot` / `config` = cd to chezmoi source dir, `J` = `just -g`, `must` = `mise run`, `y` = yazi with cwd tracking
- `CLAUDECODE` env var suppresses pokemon-colorscripts on shell start (for Claude Code sessions)
- Zim's `compinit` runs in `zim-init.zsh` — anything needing `compdef` must come AFTER that source line
- `zstyle ':completion:*:descriptions' format '[%d]'` overrides zim's format so fzf-tab can parse it
- Custom zoxide completion: always shows frecency-ranked results on tab, includes local dirs, uses `eza` preview in fzf-tab

## Atuin
- Config: `dot_config/atuin/config.toml`
- Style: compact, inline height 20, `enter_accept = false` (enter edits, not runs)
- Search mode: `daemon-fuzzy` (daemon enabled with autostart)
- `exit_mode = "return-query"`, `workspaces = true`, `ctrl_n_shortcuts = true`
- AI and sync (records mode) enabled

## FZF
- Config: `dot_zsh/fzf.zsh`
- Default command: `fd --type f --strip-cwd-prefix --hidden --follow`
- `rgf` function: ripgrep-powered live grep with fzf, opens results in nvim
- Skim (`sk`) vars mirror fzf config

## Television (tv)
- Fuzzy picker tool, init'd in zshrc
- Cable channels: `dot_config/television/cable/`
  - `zoxide.toml` — browse zoxide dirs with eza preview
  - `zellij-sessions.toml` — manage zellij sessions (attach, new, kill, delete) via custom script
- Custom script: `dot_config/television/scripts/executable_zellij-session`

## Just (global justfile)
- Config: `dot_config/just/justfile`
- `J` alias = `just -g` (runs global justfile)
- Groups: `mac` (remove-quarantine), `docker` (build/rebuild), `mcp` (inspector), `llm` (chat, pipe, respond, pick, unload, events, ui, log, restart)
- LLM tasks use `xh` for HTTP and `jaq` for JSON, target llama-swap at `localhost:8000`
- Default model: `anthropic/claude-haiku-4.5`

## 1Password
- SSH agent socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
- Biometric unlock enabled
- op plugins sourced from `~/.config/op/plugins.sh`
