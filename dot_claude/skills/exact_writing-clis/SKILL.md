---
name: writing-clis
description: >-
  The house CLI-ergonomics canon — use when designing, naming, building, or
  reviewing ANY command-line tool, from a one-off dotfiles script to an
  installed lulu-tools/lulu-agent binary. Covers naming a binary or subcommand,
  command grammar (noun-verb, root dispatcher, subcommand lifecycle), flags and
  arguments (standard names, order rules, --, wrapper CLIs), stdout/stderr
  discipline, --json and table output, exit codes, error style,
  config/state/cache paths (XDG), secrets handling, and a step-by-step
  procedure for auditing an existing CLI against the canon. Trigger on: "new
  CLI", "name this tool/command/flag", "add a subcommand", "add a flag", "CLI
  design/ergonomics/UX", "is this a good interface", redesigning or auditing a
  CLI's surface (lu, memo, speak, any scripts/ tool), writing argument parsing
  in any language (cligen, clap, anything), or reviewing a diff that
  adds/changes a CLI surface.
---

# Writing CLIs

The house canon for CLI ergonomics. Applies to **every** command-line tool built here — a 50-line Nim one-off in `scripts/`, a justfile recipe, or an installed Rust binary in lulu-tools.

## Precedence

1. **[clig.dev](https://clig.dev)** is the spine — when in doubt, do what it says.
2. **POSIX.1-2017 §12.2** is cited by guideline number (G1–G14) where it rules.
3. **Heroku CLI style guide, smallstep naming, XDG basedir spec** layer in by topic.
4. **House conventions** amend the spine; every amendment is marked `DEVIATION:` with rationale in the references. House rules are cited to real files so they stay falsifiable.

## The universal floor — every CLI, no exceptions

1. **stdout = payload, stderr = everything else** (progress, diagnostics, footers,
   narration). If Hazel/launchd invokes it, routine narration goes to stderr and
   stdout stays empty unless there's a result. [clig, Heroku, house: universal]
2. **`-h`/`--help` works from anywhere** and never means anything else. [clig]
3. **Exit codes are meaningful**: 0 success, 1 runtime failure (error body surfaced
   verbatim, never swallowed), 2 usage/precondition error caught before side
   effects. "Not my job" skips exit 0 with a stderr note (Hazel retry semantics).
   Wrappers pass the wrapped command's code through; 124 timeout / 125 setup
   failure (timeout(1)/env(1) convention, house: wezrun). [house + coreutils]
4. **`--` ends options** (POSIX G10); `-` means stdin/stdout where a file operand
   is expected (G13).
5. **No secrets in flags, ever** (they leak into ps, shell history, --help
   examples). [clig + house: the speak/elevenlabs lesson]
6. **Never require a prompt** — every prompt has a flag/arg bypass; no prompting
   when stdin isn't a tty; expected-stdin-but-tty prints help instead of hanging.
   [Heroku hard rule, clig]
7. **Errors name the tool and speak human** ("myapp: can't write to file.txt —
   run 'chmod +w file.txt'"), most important info last. [clig + house fail() proc]
8. **Every flag has a long form**; short forms only for the frequent ones. [clig]
9. **Fail before side effects** — validate first, then act. [clig]
10. **Destructive actions confirm, tiered by severity**; the refusal names both
    the limit and the exact bypass flag (house: gif-mosaic --force). [clig + house]

## The full tier — switches on when a tool graduates to installed-and-long-lived

The boundary is the scripting ladder's Nim→Rust graduation: if it's installed on
PATH and meant to live for years, the full tier applies. Everything in the floor,
plus:

- `--json` — full-fidelity structured output offered in addition to the human
  table (which stays the default); when passed, stdout carries JSON only
- grep-safe flat tables (category as a column value, CAPS header, real column
  alignment — never `====` section headers that break line filtering)
- color discipline: `NO_COLOR`, `--no-color`, `TERM=dumb`, tty-detect both streams
  independently; **red/yellow reserved for errors/warnings**
- progress/spinners only on a tty, always on stderr
- `-q`/`--quiet`
- XDG paths with the config/state/cache split
- stated config precedence: **flag > env var > config file (TOML) > built-in default**
- tool-prefixed env vars 1:1 with flags (`SPEAK_ELEVENLABS_API_KEY` >
  `ELEVENLABS_API_KEY`)
- file-based secret resolution (`--key-file` / credential file) alongside the
  env floor
- `--version`
- state-changing commands say what changed (`git push` model)
- long output pages via `less -FIRX` (interactive tty only)

## Command grammar

- **`noun verb`** for two-level subcommands (`lu sessions list`), verbs consistent
  across nouns. The bare noun lists its resources — never a `*:list`/`* list`
  duplicate. [clig "more common" + Heroku]
- **Root is a pure dispatcher** once a tool has namespaces: no bare verbs at root
  coexisting with namespaced ones (`lu stop <id>` next to `lu daemon stop` is the
  anti-pattern).
- **The accretion rule:** when a single-purpose tool grows its first second noun,
  promote the original behavior to an explicit verb in the same change (`lu` →
  `lu run`) and move its flags there. Root-level flags stay global-only.
- **No homonyms across the flag/subcommand boundary** (`lu schema` vs `--schema`
  is the cautionary example — the docs needed a "not to be confused with" warning).
- **No position-sensitive flags** ("only binds before `config`" is a bug, not a
  quirk). Exception: wrapper CLIs (memo, chain, wezrun) — the wrapped command
  starts an opaque argv tail; wrapper flags come first and `--` marks the boundary
  explicitly. A dispatcher is not a wrapper and gets no exemption.
- **No packed multi-values** (`--audio-output alloy:wav`) without strong precedent
  — separate flags, or comma-separated per POSIX G8.

## Naming quick-gate (full worksheet: references/naming.md)

Before shipping any name — binary, subcommand, or flag:

1. **Frequency test** — length scales inversely with how often it's typed
   (`lu` daily → 2 chars fine; `heic-ai-rename` niche → long is right).
2. **One-hand test** — typeable with one hand like `cat`? (smallstep)
3. **Poetry test** — would it read as a word in prose? (`curl` yes,
   `AssetCacheTetheratorUtil` no)
4. **Collision check** — `command -v <name>`, `which -a`, quick brew/crates/npm
   search.
5. **Longevity check** — not a protocol/standard/format name, not the
   implementation tech, not a generic-word land-grab (`convert`), no version
   numbers. When scope will evolve, prefer thoughtful meaninglessness.

## Gotchas

- **Wrapper flag boundary** (memo, chain, wezrun): the wrapper's own flags go
  BEFORE the wrapped command; once the command name starts, every later token
  belongs to it. `memo --tail 40 -- just build` ✓, `memo just build --tail 40` ✗.
  Always show the explicit `--` form in docs.
- **Hazel/launchd exit semantics**: a nonzero exit surfaces as "Shell script
  failed" and triggers retry. "Not my job to process this file" is a *skip* —
  stderr note + exit 0 — not a failure.
- **`-v` ruling**: `-v` = verbose (repeatable), `-V --version` = version. The
  `-V --version` binding is clap's default and matches installed
  rg/cargo/fd/bat/delta/jaq; repeatable `-v` is house convention and needs
  explicit wiring (clap `ArgAction::Count`). Domain-compat exceptions allowed
  (rg `-v` = invert-match inherits grep).
- **Skill-description auto-optimizers score CLI-usage skills at ~0% recall** —
  never regenerate this skill's description with one; it's hand-written.
- **Long options are NOT POSIX** — `--foo` is GNU getopt_long. Cite POSIX only
  for what §12 actually covers; label long-option guidance as GNU/clig.

## Reference load map

Load on the stated trigger — not preemptively, not "for completeness":

- `references/naming.md` — **when choosing or reviewing ANY name** — binary,
  subcommand, or flag. The deepest reference; includes the full worksheet and a
  worked example.
- `references/arguments-and-flags.md` — when designing or reviewing a tool's
  flag/argument surface: standard names, order rules, POSIX guidelines, prompts,
  destructive-action tiers, wrapper CLIs.
- `references/output.md` — when deciding what a tool prints where: stdout/stderr
  law, tables, `--json`/`--plain`, color, progress, pagers, footers.
- `references/errors-and-robustness.md` — when writing error paths, picking exit
  codes, or hardening a tool: error style, fail-closed vs soft-fail, timeouts,
  Ctrl-C, recoverability.
- `references/config-and-state.md` — when a tool needs config, persistent state,
  or cache: the XDG table, config/state/cache semantics, precedence chains,
  env-var conventions.
- `references/secrets.md` — when a tool touches an API key, token, or credential.
- `references/stack-bindings.md` — when implementing: the bash/just → Nim+cligen
  → Rust+clap ladder with real house snippets per rung.
- `references/auditing.md` — when reviewing an EXISTING CLI against the canon:
  the step-by-step audit procedure and violation-ordering rules.
