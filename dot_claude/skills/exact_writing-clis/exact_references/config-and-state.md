# Config, State, and Paths

Precedence: XDG Base Directory spec v0.8 for paths; clig.dev for the config
tiers and precedence; house conventions (TOML, prefixed env vars) cited to real
tools. House ruling marked below.

## HOUSE RULING: XDG everywhere, macOS included

Every CLI here uses XDG paths on every platform. `~/Library/*` is reserved for
GUI/OS-integrated apps (launchd plists, Spotlight, iCloud) — a terminal tool
never writes there. Unix-heritage macOS tools honoring `XDG_*` is normal
(neovim, tmux, fish all do).

## The seven XDG variables

| Variable | Kind | Default when unset/empty | Cardinality |
|---|---|---|---|
| `XDG_CONFIG_HOME` | config | `~/.config` | single dir |
| `XDG_DATA_HOME` | data | `~/.local/share` | single dir |
| `XDG_STATE_HOME` | state | `~/.local/state` | single dir |
| `XDG_CACHE_HOME` | cache | `~/.cache` | single dir |
| `XDG_RUNTIME_DIR` | runtime | **no default** | single dir |
| `XDG_CONFIG_DIRS` | system config search path | `/etc/xdg` | colon list |
| `XDG_DATA_DIRS` | system data search path | `/usr/local/share/:/usr/share/` | colon list |

There is no `XDG_STATE_DIRS` or `XDG_CACHE_DIRS` — state and cache are
single-user-dir only.

Mechanics (spec):

- **Write only to `_HOME` dirs**; `_DIRS` lists are read-only search paths,
  searched in order ("the first directory listed is the most important"),
  `_HOME` beating `_DIRS`. Skip inaccessible dirs and keep searching.
- **Auto-create on write** with mode **0700**.
- **A relative path in any XDG variable is invalid** — treat as unset, fall back
  to the default.
- `XDG_RUNTIME_DIR` (sockets, pipes): 0700, user-owned, login-scoped lifetime,
  local filesystem. It's the only variable with **no default** — fall back to a
  similar-capability dir AND print a warning (the others default silently). The
  fallback must itself be user-owned 0700: macOS's per-user `$TMPDIR`
  (`/var/folders/…`) qualifies as-is; on a shared tmp, create a 0700 subdir and
  reject unexpected ownership or symlinks.

## Which bucket?

- **Config** — user-authored settings. `~/.config/<tool>/config.toml`.
- **Data** — runtime-needed files that aren't config/state/cache: assets,
  templates, user-content databases.
- **State** — regenerated-not-authored, reused across restarts, not disposable:
  logs, history, recently-used lists, layout, undo history. The newest bucket,
  added precisely because these got misfiled into config and data.
- **Cache** — safe to delete entirely; only a recompute/redownload cost. If
  `rm -rf` of the dir would *lose* something, it isn't cache.

House exemplar of a full fallback chain (memo's cache dir):
`--cache-dir` flag → `LULU_CACHE_DIR` → `$XDG_CACHE_HOME/lulu` → `~/.cache/lulu`
→ `$TMPDIR/lulu-$UID`. Document the chain as a numbered list.

## Config format and tiers

**TOML is the house config format** (speak's `config.toml`, the anchors
manifest). Not YAML, not JSON, not INI.

clig's three tiers decide where a knob lives:

1. **Varies per invocation** (verbosity, dry-run) → **flags** (env vars as an
   optional supplement).
2. **Stable per machine/user** (paths, color, providers) → flags + env vars;
   a config file when there are enough of them.
3. **Stable per project, shared across users** → a version-controlled,
   command-specific config file in the repo.

## Precedence (high → low)

**flag > env var > config file > built-in default** — stated, in the docs, as a
numbered list (speak precedent). When a tool has multiple config layers, the
full deterministic chain is clig's: flag > env var > project config > user
config > system config > built-in default.

## Environment variables

- Names: uppercase letters/digits/underscores, no leading digit; single-line
  values.
- **Tool-prefixed beats generic, 1:1 with the flag it overrides**:
  `TOKENS_ANTHROPIC_API_KEY` > `ANTHROPIC_API_KEY` (avoids clobbering Claude
  Code's own auth), `SPEAK_ELEVENLABS_API_KEY` > `ELEVENLABS_API_KEY`. Check the
  prefixed name first, fall back to the generic.
- Don't collide with the POSIX standard env list; do honor the general-purpose
  ones where relevant: `NO_COLOR`/`FORCE_COLOR`, `DEBUG`, `EDITOR`, `PAGER`,
  `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY`, `TERM`, `TMPDIR`, `HOME`,
  `LINES`/`COLUMNS`.
- No invented namespaces: the only house env namespace is `LULU_*` for actual
  lulu tooling. A new tool gets `<TOOL>_*`, nothing else.
- `.env` is per-directory override sugar, **not a substitute for a real config
  file** (unversioned, string-only, encoding bugs, credential magnet).

## Robustness rules

- **A config-reference typo must never silently disable behavior** (house,
  anchor-manifest precedent): a matched rule pointing at a missing file falls
  through to the next rule *by documented design* — or errors loudly. The
  failure mode to ban is "mechanism off, nobody noticed."
- **Modifying config you don't own** requires explicit consent and a statement
  of exactly what changes. Prefer a new dedicated file (`/etc/cron.d/myapp`
  model) over appending to a shared one; if appending, leave a dated comment.

## Checklist (for audits)

- [ ] All paths XDG; nothing under `~/Library` or bare `~/.<tool>` dotfiles
- [ ] Config/data/state/cache each in the right bucket (cache deletable? state ≠ config?)
- [ ] Writes go to `_HOME` dirs, created 0700
- [ ] Config file is TOML; knobs assigned to the right clig tier
- [ ] Precedence documented: flag > env > config > default
- [ ] Env vars tool-prefixed, 1:1 with flags, generic fallback second
- [ ] `NO_COLOR` / `EDITOR` / `PAGER`-class vars honored where relevant
- [ ] Missing-file references fail loudly or fall through by documented design
