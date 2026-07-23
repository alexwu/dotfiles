# Stack Bindings

How the canon maps onto the house scripting ladder. Precedence: house conventions
throughout, cited to real files; the ladder itself is set in `~/.claude/CLAUDE.md`.

## The ladder → the tiers

| Rung | When | Canon tier |
|---|---|---|
| bash / justfile recipe | trivial, a few lines, orchestrating real binaries | universal floor |
| Nim + cligen | single-purpose, non-trivial; hook- or Hazel-invoked | universal floor |
| Rust + clap (lulu-tools workspace) | complex, performance-sensitive, installed, long-lived | **full tier** |
| `go run` | pinned one-offs | universal floor |

The full tier switches on at the Nim→Rust graduation — but a Nim tool that ends
up installed and daily-driven (`wezrun`) should absorb full-tier items as it
earns them; the tier follows the *lifecycle*, the language just correlates.

## justfile recipes (trivial rung)

Recipes orchestrate performant CLI binaries — never reimplement logic in shell.
Positionals after flags, `+variadic` last. The floor still applies: a recipe
that prints diagnostics mixes them onto stderr (`>&2`), exits nonzero on real
failure, and never truncates output it's relaying.

## Nim + cligen

**Single-command tools** use `dispatch` with an explicit `cmdName`, usage, and
per-flag help (`scripts/macos/electron_apps.nim:235-244`):

```nim
when isMainModule:
  import cligen

  dispatch(
    main,
    cmdName = "electron-apps",
    usage = "$command [--json] [ROOT ...]\n\nOptions:\n$options",
    help = {
      "json": "emit records instead of a table",
      "roots":
        "directories to scan (default: /Applications, ~/Applications, /System/Applications)",
    },
  )
```

**Multi-subcommand tools** use `dispatchMulti` with array-literal registration;
kebab-case subcommand names go in `cmdName` (`scripts/claude/persona_anchor.nim:121-125`):

```nim
when isMainModule:
  dispatchMulti(
    [sessionStart, cmdName = "session-start"],
    [promptSubmit, cmdName = "prompt-submit"],
    [resolve, cmdName = "resolve"],
  )
```

What cligen gives free: `-h/--help` everywhere, long+short forms, G5 grouping,
`--` handling, kebab↔camelCase flag aliasing. What it doesn't: your
stdout/stderr split, exit codes, and naming — the canon governs those.

House mechanics:

- A **manual arg-parse loop is the exception**, only when cligen can't express
  the shape (`scripts/hazel/image_sort.nim:285-305` precedent) — document why.
- Source filenames are valid Nim identifiers (`electron_apps.nim`); the binary
  gets the kebab name via the build script's `-o:`.
- Format with `nph`; NEP-1 style.
- **Hazel/launchd tools self-prepend `~/.local/bin` to PATH** — automation hosts
  give a minimal environment (both Hazel tools do this defensively).
- Per-binary `fail()` proc: tool-name prefix, stderr, `quit(1)`.
- When a proc name would collide with a stdlib symbol cligen pulls in, rename
  the proc and keep the public name via `cmdName` (`runningCmd` +
  `cmdName = "running"` in llm_local.nim).

## Rust + clap (full tier)

The lulu-tools workspace is the template: clap with **derive + env features**
(env-var fallback declared on the flag itself keeps the 1:1
flag↔`<TOOL>_*`-var rule honest), `bkt` for caching, reqwest with rustls-tls;
release profile `lto = "thin"`, `codegen-units = 1`.

What clap gives free: `-h/--help`, `-V/--version` when version metadata is set
(the house `-V` binding is clap's default; repeatable `-v` needs explicit
`ArgAction::Count`), `--` handling, typed value parsing, env fallbacks; shell
completions come from the separate `clap_complete` crate.
Full-tier items it does NOT give: `--json` output, table
formatting, color discipline (`NO_COLOR` et al.), XDG paths, config-file
precedence — those are yours to build, per the canon.

## Wrapper CLIs (any rung)

memo, chain, wezrun: wrapper flags before the wrapped command, `--` boundary
explicit in docs, wrapped command's exit code passed through, 124/125 for
timeout/setup (see `errors-and-robustness.md`). Sentinel-based completion
detection and scrollback capture (wezrun) stay inside the wrapper — the wrapped
command never needs to cooperate.

## Checklist (for audits)

- [ ] Tool sits on the right rung; full tier applied if installed + long-lived
- [ ] Nim: cligen `dispatch`/`dispatchMulti`, kebab `cmdName`s, per-flag help
- [ ] Manual parsing only with a documented reason
- [ ] Automation-invoked: PATH self-prepend present
- [ ] Rust: clap derive + env; env fallbacks declared on flags
- [ ] Free parser behavior not fought (no hand-rolled `--help`, no `-V` rebind)
