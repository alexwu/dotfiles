# Chezmoi

## Structure
- `dot_*` files are chezmoi-managed — edits require `chezmoi apply` to go live
- `executable_` prefix = chezmoi sets the execute bit on apply
- `private_Library/` = macOS ~/Library paths (LaunchAgents, Application Support)
- Root-level config files (`mise-config.toml`, `claude-settings.json`, `codex-config.toml`, `zed-settings.json`) are **symlink targets** — their real configs point INTO this repo, so edits are live immediately without `chezmoi apply`. Listed in `.chezmoiignore` to prevent deployment to `~/`.

## Chezmoi Internals
- `.chezmoiexternal.toml` — external git repos pulled into managed dirs (currently: pokemon-colorscripts)
- `.chezmoidata/packages.yaml` — Homebrew brews, head brews, and casks installed via `run_onchange_install-packages.sh.tmpl`
- `run_onchange_install-packages.sh.tmpl` — runs `brew bundle` from the packages data; re-runs when packages.yaml changes
- Neovim is installed as a **HEAD brew** (`neovim --HEAD`) — targets nightly builds
- `empty_dot_hushlogin` — creates empty `~/.hushlogin` to suppress macOS login banner
- `chezmoi destroy <target>` removes from BOTH source state and destination. `chezmoi forget` only drops from source state (leaves deployed file). Use `destroy` to fully retire a managed file.
- `chezmoi apply` runs every changed template — if you only want one target rebuilt while other files are dirty, run the underlying command directly (e.g. `nim c -o:~/.local/bin/X scripts/.../X.nim`) and let the source hash sync on the next full apply.

## Other Notable Configs
- `dot_ideavimrc` — JetBrains IdeaVim config
- `dot_vimrc` — traditional Vim fallback config
- `dot_default-gems`, `dot_default-npm-packages` — auto-installed packages for new Ruby/Node versions
- `dot_config/private_fish/` — Fish shell config (secondary shell)
- `dot_config/skhd/` — skhd hotkey daemon config
- `dot_config/opencode/` — OpenCode AI config
- `dot_config/gh/` — GitHub CLI config
- `dot_config/gitui/` — GitUI terminal git client config
- `dot_zoxide.nu`, `dot_nu/` — Nushell config fragments
