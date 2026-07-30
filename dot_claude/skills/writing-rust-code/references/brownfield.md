# Brownfield: retrofitting idioms into existing code

Load when touching a repo that predates these rules, or when asked to "make it
idiomatic" / "clean this up". The house situation this was written for:
`lulu-agent` and `beam` already pass the full bar; `lulu-tools` (and other
pre-bootstrap-skill repos) don't. The goal is convergence without churn.

## Boy-scout boundaries (the non-negotiable part)

Raise what you touch to canon; never rewrite the neighborhood.

- **Scope = the diff you were asked for.** New/edited functions get the full
  ruleset (let-else, typed errors, `# Errors` docs, no naked unwrap). The
  untouched function above it stays untouched — even if it's ugly.
- **Don't cascade.** Converting one function's `Result<T, String>` to a typed
  error may force signature changes up the call chain — that's fine when small;
  when it fans out past a handful of call sites, stop and surface it as its own
  task instead of burying a refactor inside a feature diff.
- **Never start an idiom sweep uninvited.** "While I was in there I
  modernized 600 lines" is a review burden nobody asked for. Propose it; let
  Alex decide.
- Formatting churn: don't re-wrap or reorder code you didn't semantically
  change. The diff should read as the change, not as weather.

## The lint-escalation ladder

You cannot drop pedantic-at-deny onto a legacy workspace — the first commit
dies under 300 warnings. Climb:

1. **Fix dead config first.** If `clippy.toml` sets thresholds, add the
   `[workspace.lints.clippy]` entries that enable those lints (a threshold with
   no enabled lint has never fired — see the SKILL.md gotcha). Start them at
   `warn`.
2. **Default clippy at deny.** `cargo clippy --all-targets --all-features --
   -D warnings` in the gate (justfile `lint` recipe + prek hook), and get it to
   zero. This alone catches the worst.
3. **Cherry-pick pedantic lints in**, one at a time: enable at `warn`, burn the
   violations down to zero, then it's automatically deny via the gate's
   `-D warnings`. Prioritize the ones with teeth:
   `clippy::too_many_lines`, `clippy::cognitive_complexity` (enable it — the
   threshold is already configured), `clippy::must_use_candidate`,
   `clippy::missing_errors_doc`, `clippy::redundant_clone`.
4. **End state: blanket `pedantic = { level = "warn", priority = -1 }`** with
   the deny gate — the greenfield default (`lulu-agent`/`beam` tier). Every
   surviving `#[allow]` carries its justification comment.

Exemplar projects (ripgrep, jj, ruff) stop at step 2-3 permanently; house
policy is step 4 — the ladder is the route, not a place to live.

## Structural retrofits, ordered by leverage

When an idiom sweep IS the task, this is the order (highest payoff per line
changed first):

1. **`Result<T, String>` → thiserror enums.** Start at the crate whose errors
   cross a boundary (HTTP router, exit codes) — that's where string-sniffing
   breakage lives. Model on `nxm`'s `NxmError`; move status/exit mapping onto
   the type as a method.
2. **Wire the shared crate.** Duplicated helpers (sigpipe reset, secret
   resolution, XDG paths) move to the workspace's shared crate — and every
   binary's `Cargo.toml` actually depends on it. A shared crate with zero
   consumers (the current `lulu-config` state) fixes nothing.
3. **`.lock().unwrap()` clusters → `parking_lot`** (or one poison-recovering
   accessor if std must stay). Mechanical, high-count, zero behavior change.
4. **Split oversized files at concern boundaries.** A 900-line `main.rs` with
   seven subcommands' arg-handling wants one module per subcommand. Move code
   verbatim first, commit, then idiomize — two reviewable steps, not one blob.
5. **Bare `#[allow]`s**: each gets a justification comment or gets fixed —
   deciding which is usually a five-minute judgment per site.

## Audit commands (measure before and after)

```sh
# unwrap/expect density outside tests (eyeball the hits — cfg(test) modules inline)
rg -n '\.unwrap\(\)|\.expect\(' crates/ -g '!*test*' -g '*.rs'

# stringly-typed error surfaces
rg -n 'Result<[^,]+,\s*String>' crates/

# bare allows (no comment on the same or preceding line — verify by reading)
rg -n '#\[allow\(clippy::' crates/

# file-length outliers
fd -e rs . crates/ -x wc -l | sort -rn | head -20

# duplicated helpers across sibling binaries
rg -l 'fn reset_sigpipe' crates/
```

Run them before starting (baseline) and after (proof). A retrofit PR that
can't show its numbers moving is churn.
