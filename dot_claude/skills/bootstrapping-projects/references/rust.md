# Rust project bootstrap

Grounded in `lulu-agent` — the most thought-out Rust project, strict from line
one. Defer Rust *idioms* to the `writing-rust-code` skill; this reference owns
**layout + dependencies + the quality gate**. (`pi-agent-rust` is a
repo-specific workflow skill for `pi_agent_rust`, not a style canon — don't
route to it for idioms.)

## Layout — workspace from day one

Always scaffold a Cargo **workspace** with crates under `crates/`, even for a
single crate. Adding crate #2 is then zero-friction, and dependencies are
centralized from the start.

```text
my-project/
├── Cargo.toml            # [workspace] — members, package defaults, lints, deps
├── rust-toolchain.toml
├── rustfmt.toml
├── clippy.toml
├── prek.toml
├── justfile
├── .github/workflows/ci.yml
├── AGENTS.md             # conventions for future agents
└── crates/
    └── my-project-cli/
        ├── Cargo.toml    # uses `.workspace = true` for shared deps
        └── src/
```

### Root `Cargo.toml`

```toml
[workspace]
resolver = "3"
members = ["crates/my-project-cli"]

[workspace.package]
edition = "2024"
version = "0.0.0"
license = "MIT"
rust-version = "1.95"   # pin; bump deliberately

[workspace.lints.clippy]
# Opinionated extra lints — cheap to satisfy on a fresh codebase. priority -1 so
# any per-lint `allow` added later overrides the group.
pedantic = { level = "warn", priority = -1 }
# cognitive_complexity is allow-by-default; enable it so the clippy.toml
# threshold actually guards.
cognitive_complexity = "warn"

[workspace.dependencies]
# Internal crates as path deps; members pull them via `.workspace = true`.
my-project-cli = { path = "crates/my-project-cli" }

# Every shared dep lives here with a `# why` comment. Verify versions/choices
# against current docs (find-docs / ctx7) — don't pick from memory.
clap = { version = "4", features = ["derive"] }   # CLI parsing
serde = { version = "1", features = ["derive"] }   # serialization
serde_json = "1"
thiserror = "2"   # error types in libraries
anyhow = "1"      # error handling at the CLI/binary edge
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# Dev / test
assert_cmd = "2"
tempfile = "3"
```

Member crate `Cargo.toml`:

```toml
[package]
name = "my-project-cli"
edition.workspace = true
version.workspace = true
license.workspace = true

[lints]
workspace = true   # inherit [workspace.lints]

[dependencies]
clap.workspace = true
anyhow.workspace = true
```

## Toolchain — pin stable, format with nightly

`rust-toolchain.toml`:

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
```

**Codified split:** lint / build / test run on `+stable`; **`fmt` runs `+nightly`**
because the richer `rustfmt.toml` options (`wrap_comments`,
`imports_granularity`, `comment_width`, `group_imports`) are nightly-only. The
justfile recipes pin `+stable` / `+nightly` per-recipe so this is invisible day to day.

`rustfmt.toml`:

```toml
edition = "2024"
tab_spaces = 2
max_width = 120
comment_width = 100
format_code_in_doc_comments = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
wrap_comments = true
reorder_impl_items = true
newline_style = "Unix"
```

## Complexity + size caps (the anti-sprawl gate)

`clippy.toml`:

```toml
cognitive-complexity-threshold = 30
too-many-arguments-threshold = 8
# Proper nouns clippy::doc_markdown shouldn't flag. ".." keeps clippy defaults.
doc-valid-idents = ["OpenAI", ".."]
```

- `clippy::pedantic` already brings `too_many_lines` (per-**function** length),
  `must_use_candidate`, `missing_errors_doc`, etc.
- **No `unsafe`** by default.

### Max-FILE-length cap (headline anti-sprawl rule)

Clippy has **no native file-length lint** — `too_many_lines` caps *functions*,
not files. There is no good Rust-specific tool for this. Use the **shared
`wc -l` hook** (`assets/check-file-lines.sh` in this skill): copy it into the new
project as `scripts/check-file-lines.sh`, `chmod +x`, and wire it as a `prek`
local hook (see the `prek.toml` below). Cap with `FILE_LINE_MAX` (default 400).

Add the function-level complement to `clippy.toml` so functions are capped too:

```toml
too-many-lines-threshold = 100   # per-function; pedantic default is 100
```

## Test — nextest + TDD

- Tests run via **`cargo nextest`**, not `cargo test`.
- **TDD always:** Red → verify-red → minimal green → commit at GREEN.
- Run with `--all-features` so feature-gated code is type-checked + linted too.
- **Live/integration tests are feature-gated** and skip when prereqs (a server,
  an API key) are missing — keep `just test` hermetic.

## Pre-commit gate — `prek.toml`

```toml
#:schema https://www.schemastore.org/prek.json

[[repos]]
repo = "builtin"
hooks = [
  { id = "trailing-whitespace" },
  { id = "end-of-file-fixer" },
  { id = "check-added-large-files" },
  { id = "check-merge-conflict" },
  { id = "detect-private-key" },
]

[[repos]]
repo = "local"

[[repos.hooks]]
id = "cargo-fmt"
name = "cargo fmt --check"
entry = "cargo +nightly fmt --all --check"
language = "system"
files = '\.rs$'
pass_filenames = false
stages = ["pre-commit"]

[[repos.hooks]]
id = "cargo-clippy"
name = "cargo clippy -D warnings"
entry = "cargo +stable clippy --all-targets --all-features -- -D warnings"
language = "system"
files = '\.rs$'
pass_filenames = false
stages = ["pre-commit"]

[[repos.hooks]]
id = "file-line-limit"
name = "file line limit"
entry = "scripts/check-file-lines.sh"   # copied from this skill's assets/
language = "script"
files = '\.rs$'
stages = ["pre-commit"]

# + actionlint on .github/workflows/*.yml if you have CI
```

Install with `prek install` (see the `prek` skill). Never bypass with `--no-verify`.

## `justfile` — the single local gate

The full reference lives in the `writing-justfiles` skill; the spine:

```just
set positional-arguments

default:
    @just --list

# nightly fmt so the rustfmt.toml options are honored
fmt:
    cargo +nightly fmt --all

fmt-check:
    cargo +nightly fmt --all --check

# warnings are errors; --all-features so feature-gated code is linted
lint *ARGS:
    cargo +stable clippy --all-targets --all-features "$@" -- -D warnings

test *ARGS:
    cargo +stable nextest run --all-features "$@"

# the one local gate — CI runs these same recipes
check: fmt-check lint test

hooks:
    prek run --all-files
```

## CI

`.github/workflows/ci.yml` drives the **same `just` recipes** (one source of flag
truth) across `fmt-check` / `lint` / `build` / `test`. Pin third-party action
refs to commit SHAs (Dependabot bumps them).

## Default dependency reaches (verify with ctx7 before adopting)

| Need | Reach for |
|------|-----------|
| CLI args | `clap` (derive) |
| Errors (lib) | `thiserror` |
| Errors (edge) | `anyhow` |
| Serialization | `serde` + `serde_json` / `toml` |
| Async | `tokio` (`features = ["full"]`) |
| Logging | `tracing` + `tracing-subscriber` |
| HTTP | `reqwest` |
| JSON Schema | `schemars` |
| Time | `jiff` |
| IDs | `uuid` (v7) |
| POSIX calls | `rustix` (never raw `unsafe { libc::... }` when a wrapper exists) |
| Sync locks | `parking_lot` (no poisoning) |
| Builders | `bon` |
| Enum utilities | `strum` |
| Test process | `assert_cmd`; HTTP mock: `wiremock`; temp files: `tempfile` |
