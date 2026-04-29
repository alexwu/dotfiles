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
- `chezmoi destroy <target>` removes from BOTH source state and destination. `chezmoi forget` only drops from source state (leaves deployed file). Use `destroy` to fully retire a managed file.
- `chezmoi apply` runs every changed template — if you only want one target rebuilt while other files are dirty, run the underlying command directly (e.g. `nim c -o:~/.local/bin/X scripts/.../X.nim`) and let the source hash sync on the next full apply.

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
- `scripts/claude/git_add_guard.nim` is a PreToolUse Bash hook that blocks bulk `git add` forms (`-A`, `--all`, `.`, `-u`, `--update`) to force explicit-path staging. Pass-through for `git add <path>`, `git add dir/`, `git add -p`, and non-`git add` commands. Trailing `(\s|$)` on each blocked pattern prevents `--all-hands` / `.bashrc` false-positives.
- `scripts/claude/git_readonly_guard.nim` is a PreToolUse Bash hook scoped via subagent frontmatter to `code-explorer` (NOT global). Splits the command on shell chaining (`|`, `;`, `&`, backtick, `$(`, newline); for each segment that starts with `git`, allows only the read-only verb allowlist (`log`, `diff`, `show`, `blame`, `status`, `reflog`, `shortlog`, `grep`, `ls-files`, `ls-tree`, `cat-file`, `rev-parse`, `rev-list`, `describe`, `name-rev`, `merge-base`); anything else returns `permissionDecision: "deny"`. Non-git segments pass through untouched. Compound commands like `true && git push` are caught because the splitter handles `&&`.

## Custom skills
- `dot_claude/skills/plan-mode-plans/` — base skill loaded automatically when entering plan mode (per `~/.claude/CLAUDE.md` rule). Defines the explore→clarify→draft→exit-plan-mode workflow with self-containment requirements.
- `dot_claude/skills/plan-mode-plans-tdd/` — variant with TDD red-green-refactor steps.
- `dot_claude/skills/plan-mode-plans-agent-teams/` — variant that dispatches parallel exploration via agent teams.
- `dot_claude/skills/plan-mode-plans-agent-teams-tdd/` — combined TDD + agent-teams variant.
- Each skill is a single `SKILL.md` file with frontmatter (`name`, `description`) plus the body. Loaded by Claude Code automatically when its description matches.

## Custom subagents
- `dot_claude/agents/code-explorer.md` — local-codebase research. Sonnet, `tools: Read, Grep, Glob, Bash`, `memory: project`, preloads `ast-grep` skill, frontmatter PreToolUse hook on `Bash` matcher → `git-readonly-guard`. System prompt bans `find | xargs grep`, `| head -N` truncation, training-data recall.
- `dot_claude/agents/github-explorer.md` — GitHub-only remote research (code, issues, PRs, releases, tags, commits). Sonnet, full GitHub MCP read-only allowlist + Read + Bash for `gh` CLI fallback, `memory: user`. System prompt bans `git clone` for exploration; non-GitHub repos get bounced back to `web-explorer`.
- `dot_claude/agents/web-explorer.md` — library/framework/API docs and general web research. Sonnet, `mcp__plugin_context7_context7__{resolve-library-id,query-docs}` + WebFetch + WebSearch, preloads `firecrawl-{search,scrape,map}` skills, `memory: user`. System prompt mandates context7 first, bans sequential WebSearch chains and training-data recall.
- Built-in `Explore` is disabled via `permissions.deny: ["Agent(Explore)"]` in `claude-settings.json`. Future broad-exploration delegations match against the three custom agents by description, or fall through to `general-purpose`.
- `scripts/claude/notify.nim` is a Stop/Notification/PreToolUse hook. cligen `dispatchMulti` dispatches on the first positional arg (`Stop`/`Notification`/`PreToolUse`). Backends are pluggable via a module-level `notifiers: array[N, Notifier]` — to add one, write a `proc(n: Notification): seq[seq[string]]` returning argv-lists (or `@[]` to decline) and append. `apprise` + `grrr` (zellij-only click-to-focus) are built-in.
- `scripts/claude/sec_guard.nim` is a PreToolUse Edit/Write/MultiEdit hook (+ SessionEnd cleanup via cligen `dispatchMulti check|cleanup`). Nim port of the upstream `security-guidance` plugin (which is disabled in `enabledPlugins` in favor of this). 9 rules in a module-level `seq[Rule]`. Uses `permissionDecision: "ask"` by default (`SEC_GUARD_MODE=deny` for legacy blocking behavior). Session-scoped dedup via `~/.claude/security_warnings_state_<sid>.json`.
- `scripts/claude/persona_anchor.nim` is a SessionStart + UserPromptSubmit hook (cligen `dispatchMulti session-start|prompt-submit`) that re-injects a compressed CLAUDE.md recap as `hookSpecificOutput.additionalContext` to combat character/instruction drift. `session-start` always fires (matchers `startup|resume|compact|clear`); `prompt-submit` is counter-gated, fires every Nth call (default N=10). State file `~/.claude/persona_anchor_state_<sid>.json` ({count, last_fired_at}) survives `--resume`/`--continue`. Knobs: `ENABLE_PERSONA_ANCHOR=0` (kill switch), `PERSONA_ANCHOR_FREQUENCY=N` (override default 10). Edit `reminderText` const + rebuild to update the recap. Inspired by SillyTavern's Author's Note (depth+frequency) pattern.

## Nim gotchas (this repo)
- Source filenames must be valid Nim identifiers — underscores, not hyphens (`secret_guard.nim`, NOT `secret-guard.nim`). Binary output name (`-o:`) can still use hyphens.
- `std/re` can't compile patterns at `const` time in Nim 2.2+ — use `let` for module-level regex
- `nph` lives in `~/.nimble/bin/`; once zshrc is applied, it's on PATH via `path=(${NIMBLE_DIR:-$HOME/.nimble}/bin $path)`. `nimble shellenv` is project-scoped — NOT for rc-file use.
- `std/md5` is deprecated in Nim 2.2+ (points at the `checksums` nimble pkg). Stdlib version still works — wrap the import in `{.push warning[Deprecated]: off.}` / `{.pop.}` if you don't want the extra dep.
- For Nim CLIs with args/subcommands, use `cligen` (`dispatch` or `dispatchMulti`). Build stanza must `nimble install -y cligen` before `nim c` — see the `notify` stanza in `run_onchange_build-scripts.sh.tmpl` for the `nimble path cligen || nimble install` guard pattern.

## Claude Code hooks
- Global settings at `~/.claude/settings.json` — NOT chezmoi-managed
- `PreToolUse` + `matcher:"Bash"` hook reads `tool_input.command` as JSON on stdin
- Deny JSON: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
- **Gotcha:** inline test payloads containing sensitive strings (e.g. `echo '{"tool_input":{"command":"cat ~/.ssh/id_rsa"}}' | hook`) trip the hook because YOUR bash command contains the sensitive path. Put test payloads in a `/tmp/*.sh` script and `bash` it.
- After editing settings.json, open `/hooks` or start a new session so the watcher picks up changes
- Non-Bash events work too: `Stop`, `Notification`, `SubagentStop`, etc. — each is its own top-level key in `hooks`. `PreToolUse` accepts `matcher: "<tool name>"` for any tool (e.g. `"AskUserQuestion"`), not just `"Bash"`. Scope narrowly — without a matcher, the hook fires on every tool invocation.
- **Gotcha:** `/plugin` disable rewrites `claude-settings.json` and can strip unrelated hook entries. Disabling `security-guidance` via `/plugin` also removed my Stop/Notification/AskUserQuestion notify hooks. Always `git diff claude-settings.json` after any `/plugin` action and restore anything that got wiped.
- `PreToolUse` decision output in `hookSpecificOutput`: `permissionDecision: "allow" | "deny" | "ask"` + `permissionDecisionReason`. Plus `updatedInput: { ... }` to rewrite the tool call entirely (e.g. rewrite `grep` → `rg`). Use `"ask"` for advisory/reminder hooks; `"deny"` is a hard block that can even prevent writing documentation *about* the hook's own trigger patterns.
- Per-hook settings.json fields: `if: "Edit(*.ts)"` (permission-rule-syntax filter for tool+path; tool name appears to be required, alternation like `Edit|Write(*.py)` unverified), `statusMessage: "..."` (custom spinner text), `timeout: 5` (override the 600 s default for hot-path hooks that should never legitimately hang).
