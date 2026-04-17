# Chezmoi Dotfiles

## Structure
- `dot_*` files are chezmoi-managed — edits require `chezmoi apply` to go live
- `executable_` prefix = chezmoi sets the execute bit on apply
- `private_Library/` = macOS ~/Library paths (LaunchAgents, Application Support)
- Root-level config files (`mise-config.toml`, `claude-settings.json`, `codex-config.toml`, `zed-settings.json`) are **symlink targets** — their real configs point INTO this repo, so edits are live immediately without `chezmoi apply`. Listed in `.chezmoiignore` to prevent deployment to `~/`.

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

## Scripts
- `dot_claude/scripts/executable_dictate.py` — streaming dictation via Voxtral Realtime
  - Uses PEP 723 inline deps (`uv run --script`), no separate requirements file
  - Connects to mlx_audio.server WebSocket at `/v1/audio/transcriptions/realtime`
  - `--start-server` spawns uvicorn in single-process mode on port 8800

## Chezmoi Internals
- `.chezmoiexternal.toml` — external git repos pulled into managed dirs (currently: pokemon-colorscripts)
- `.chezmoidata/packages.yaml` — Homebrew brews, head brews, and casks installed via `run_onchange_install-packages.sh.tmpl`
- `run_onchange_install-packages.sh.tmpl` — runs `brew bundle` from the packages data; re-runs when packages.yaml changes
- Neovim is installed as a **HEAD brew** (`neovim --HEAD`) — targets nightly builds
- `empty_dot_hushlogin` — creates empty `~/.hushlogin` to suppress macOS login banner

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

## mise
- Config: `mise-config.toml` (symlink target — edits are live, no `chezmoi apply`)
- `settings.pipx.uvx = true` — pipx tools use uvx
- `settings.npm.bun = true` — npm tools use bun
- `settings.python.uv_venv_auto = true` — auto-create venvs with uv
- Rust toolchain: `nightly`
- Key tools: ruby, uv, bun, zig, rust, go, ruff, usage, cargo-binstall, petname, qsv, firecrawl-cli, playwright

## Git
- Pager: **delta** (side-by-side, with decorations theme)
- Diff tool: **difftastic** (`git difftool` uses `difft`)
- Default branch: `main`, branch sort: `-committerdate`
- GPG signing off by default (`commit.gpgsign = false`)
- SSH signing program: 1Password (`op-ssh-sign`)
- LFS enabled
- `core.fsmonitor = false`

## AeroSpace (tiling WM)
- Config: `dot_aerospace.toml` — tiling window manager for macOS
- Starts at login, uses vim-style navigation (alt+hjkl for focus, alt+shift+hjkl for move)
- Workspace assignments: 0=Slack (built-in monitor), 1=Main (WezTerm, Arc, Dia, Figma), 2=Notes (Things, Notion, Obsidian), 3=Dev (Ghostty, Warp, Zen, Xcode), 4=Chat/Email, 5=Remote (Parsec, Moonlight)
- `exec-on-workspace-change` triggers a Raycast extension for workspace display
- Service mode: `alt+shift+;`, join mode: `alt+shift+/`
- Floating exceptions: System Preferences, CleanShot, Chromium, Fantastical, Wispr Flow, Aqua Voice

## JankyBorders
- Config: `dot_config/borders/executable_bordersrc`
- Round style, width 6.0, active color: glow white, inactive: dim gray
- Blacklist: iPhone Mirroring, Dropover

## Terminal Emulators

### Ghostty
- Config: `dot_config/ghostty/config.ghostty`
- Font: Fira Code Retina + FiraCode Nerd Font Mono, size 14
- Theme: Snazzy, background opacity 0.85 with macOS glass blur
- `auto-update-channel = tip` (follows tip/nightly)
- Quick terminal: `super+backtick`

### WezTerm
- Config: `dot_config/wezterm/wezterm.lua`
- Plugins: smart_workspace_switcher (zoxide-backed), sessionizer, resurrect (workspace save/restore), smart-splits (nvim integration), toggle_terminal
- Color scheme: Snazzy, font: Fira Code weight 450 with Nerd Font fallback
- WebGpu frontend, background opacity 0.90 with macOS blur
- `cmd+d` toggles vsplit with zoom behavior, `cmd+k` switches workspace via zoxide
- `cmd+shift+n` creates new named workspace
- `cmd+shift+p` opens command palette (with rename tab/workspace, save/restore workspace)
- smart-splits: `ctrl+hjkl` for movement (passes through to nvim), `meta+arrows` for resize
- `wezterm-switch-workspace` shell function uses user-var protocol to switch workspaces from CLI

### Kitty
- Config: `dot_config/kitty/kitty.conf`
- Font: Fira Code, Nerd Font via `symbol_map`, size 14
- Remote control enabled (`allow_remote_control yes`, `listen_on unix:/tmp/mykitty`)
- Layout: splits, theme: snazzy.conf (included)
- `macos_option_as_alt yes`
- Navigation integrated with nvim via `pass_keys.py` kitten (`ctrl+hjkl`)

## Neovim
- Primary config: `dot_config/nvim/` — lazy.nvim, targets Neovim 0.12+ nightly, has its own `CLAUDE.md`
- Experimental config: `dot_config/pack-nvim/` — uses `vim.pack` (builtin plugin manager), single-file, has its own `CLAUDE.md`
- Launch experimental: `NVIM_APPNAME=pack-nvim nvim` (aliased as `envim`)
- Dev plugins load from `~/Code/neovim/plugins/` (patterns: `alexwu`)
- Colorscheme: **snazzy** (`alexwu/nvim-snazzy` + `rktjmp/lush.nvim`)
- Formatter: Lua files use **stylua** — always run before committing nvim config changes

## Neovide
- Config: `dot_config/neovide/config.toml`
- Font: Fira Code + FiraCode Nerd Font, size 14
- `NEOVIDE_FORK=1` and `NEOVIDE_MULTIGRID=true` set in zshrc

## Zellij
- Config: `dot_config/zellij/config.kdl`
- Theme: snazzy (custom defined in config)
- Default mode: **locked** — `ctrl+g` to unlock
- Meh key bindings (`ctrl+alt+shift+*`) work in both normal and locked modes for tab navigation/creation
- vim-zellij-navigator plugin for `ctrl+hjkl` passthrough to nvim
- `room.wasm` plugin: `ctrl+y` for quick session jumping
- `zsm.wasm` plugin: session manager with resurrectability (bound to `z` in session mode)
- zjstatus + zjstatus-hints plugins loaded at session start
- `pane_frames false`, `support_kitty_keyboard_protocol false`
- `ZELLIJ_SOCKET_DIR=/tmp/zellij` set in zshrc
- `zjn` alias creates new session with DBZ petname

## Television (tv)
- Fuzzy picker tool, init'd in zshrc
- Cable channels: `dot_config/television/cable/`
  - `zoxide.toml` — browse zoxide dirs with eza preview
  - `zellij-sessions.toml` — manage zellij sessions (attach, new, kill, delete) via custom script
- Custom script: `dot_config/television/scripts/executable_zellij-session`

## Yazi
- Config: `dot_config/yazi/yazi.toml`
- `show_hidden = true`
- Git status fetcher prepended for all files/dirs
- Shell wrapper `y()` in zshrc tracks cwd changes

## Just (global justfile)
- Config: `dot_config/just/justfile`
- `J` alias = `just -g` (runs global justfile)
- Groups: `mac` (remove-quarantine), `docker` (build/rebuild), `mcp` (inspector), `llm` (chat, pipe, respond, pick, unload, events, ui, log, restart)
- LLM tasks use `xh` for HTTP and `jaq` for JSON, target llama-swap at `localhost:8000`
- Default model: `anthropic/claude-haiku-4.5`

## Atuin
- Config: `dot_config/atuin/config.toml`
- Style: compact, inline height 20, `enter_accept = false` (enter edits, not runs)
- Search mode: `daemon-fuzzy` (daemon enabled with autostart)
- `exit_mode = "return-query"`, `workspaces = true`, `ctrl_n_shortcuts = true`
- AI and sync (records mode) enabled

## Lazygit
- Config: `private_Library/private_Application Support/lazygit/config.yml`
- Editor preset: nvim
- `autoFetch: false`, log order: topo-order
- Theme: dark with green inactive borders

## Sketchybar
- Config: `dot_config/sketchybar/` — Lua-based config (`init.lua`, `bar.lua`, `default.lua`)
- Has AeroSpace workspace plugin at `plugins/executable_aerospace.sh`

## Petname (DBZ)
- Custom word lists: `dot_config/petname-dbz/` (adjectives + nouns, empty adverbs)
- `dbzname` alias generates Dragon Ball Z themed random names
- Used by `zjn` (zellij) and `zn` (zmx) aliases for session naming

## FZF
- Config: `dot_zsh/fzf.zsh`
- Default command: `fd --type f --strip-cwd-prefix --hidden --follow`
- `rgf` function: ripgrep-powered live grep with fzf, opens results in nvim
- Skim (`sk`) vars mirror fzf config

## 1Password
- SSH agent socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
- Biometric unlock enabled
- op plugins sourced from `~/.config/op/plugins.sh`

## Hammerspoon
- Config: `dot_hammerspoon/` — contains `init.lua` and AeroSpace overview script

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

## Scripts
- `scripts/<domain>/` at repo root — source only, ignored by chezmoi; binaries compile to `~/.local/bin/`
- `run_onchange_build-scripts.sh.tmpl` — chezmoi rebuilds on source-hash change (`include … | sha256sum`), skips cleanly if compiler missing
- `scripts/claude/secret_guard.nim` is a PreToolUse Bash hook that gates commands **reading content from** sensitive paths — not anything that merely mentions one. Splits the command on shell chaining (`|`, `;`, `&`, backtick, `$(`); for each segment, denies when the leading program is a content-reader (`cat`/`bat`/`rg`/`head`/`cp`/`curl`/`scp`/`openssl`/`jq`/`tar`/etc.) AND the segment mentions a sensitive path. Non-readers (`ls`/`eza`/`stat`/`echo`/`printf`/`git commit`/`git log`/…) pass through regardless of argument contents — that's why `git commit -m "…about .env…"` no longer false-positives. Sensitive paths covered: SSH keys, `.env`/`.envrc`, cloud creds, age/sops, rclone/ngrok/fnox/Copilot tokens, atuin sync key. Known miss: `ls ~/.ssh/ | xargs cat` — per-segment reasoning can't correlate listings with downstream readers (a full shell parser would be needed).

## Nim gotchas (this repo)
- Source filenames must be valid Nim identifiers — underscores, not hyphens (`secret_guard.nim`, NOT `secret-guard.nim`). Binary output name (`-o:`) can still use hyphens.
- `std/re` can't compile patterns at `const` time in Nim 2.2+ — use `let` for module-level regex
- `nph` lives in `~/.nimble/bin/`; once zshrc is applied, it's on PATH via `path=(${NIMBLE_DIR:-$HOME/.nimble}/bin $path)`. `nimble shellenv` is project-scoped — NOT for rc-file use.

## Claude Code hooks
- Global settings at `~/.claude/settings.json` — NOT chezmoi-managed
- `PreToolUse` + `matcher:"Bash"` hook reads `tool_input.command` as JSON on stdin
- Deny JSON: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
- **Gotcha:** inline test payloads containing sensitive strings (e.g. `echo '{"tool_input":{"command":"cat ~/.ssh/id_rsa"}}' | hook`) trip the hook because YOUR bash command contains the sensitive path. Put test payloads in a `/tmp/*.sh` script and `bash` it.
- After editing settings.json, open `/hooks` or start a new session so the watcher picks up changes
