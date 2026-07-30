---
name: writing-rust-code
description: >-
  Writes idiomatic, readable, modern Rust (edition 2024) that stays maintainable
  for humans and legible to AI agents. Use whenever writing, editing, reviewing,
  or refactoring Rust — any .rs file or Cargo workspace, including small CLI
  crates. Covers error-type design (thiserror vs anyhow boundaries, never
  Result<T, String>), unwrap/expect policy, let-else and if-let chains, API
  design (derives, builders, newtypes, visibility), macro judgment (when
  macro_rules!/derive/proc-macro beat a plain function — and when they don't),
  lint wiring ([workspace.lints] + clippy.toml pairing), and retrofitting these
  idioms into existing non-idiomatic code without rewriting the world. Triggers
  on "idiomatic Rust", "clean this up", "is this readable", error-handling
  design, macro decisions, clippy config questions, or reviewing any Rust diff.
---

# Writing Rust Code

Idiomatic modern Rust, optimized for **readability by humans and agents alike**.
Grounded in the house codebases: `lulu-agent` and `beam` are the proof the rules
work (zero production `unwrap()`s, pedantic clippy passing clean at deny level);
`lulu-tools` is the proof of what their absence costs (dead lint config,
stringly-typed errors, 9 copies of the same helper). The gap between those repos
is discipline plus wiring, not effort — this skill is the wiring.

The organizing principle behind every rule here (Alex's stated dev philosophy):
**sane defaults that remove boilerplate, still easily extendible or overridable
when needed.** The default path costs near-zero ceremony; every default has an
obvious override seam. Provided trait methods with an assoc const, `bon`
builders, `#[default]` variants, derives-with-attribute-overrides are all this
one idea. Its two failure modes: zero-boilerplate but sealed (no override
seam), and flexible but ceremony-heavy (boilerplate at every call site).

This skill owns **how the code reads**. Project scaffolding, the quality gate,
and default dependencies belong to `bootstrapping-projects` (its
`references/rust.md`); don't restate them, route to them.

## The two postures (decide this first)

- **Writing new code — any repo, however messy.** Every rule below applies at
  full strength. A new function in a legacy crate still gets `let-else`, typed
  errors, `# Errors` docs, and no naked `unwrap`. The surrounding file's style
  is not a license.
- **Touching existing code.** Boy-scout rule with hard boundaries: raise what
  you touch to canon; never rewrite the neighborhood. "Make it idiomatic"
  sweeps, lint escalation, and structural retrofits are their own deliberate
  task — read `references/brownfield.md` before starting one, and before
  suggesting one uninvited.

## Core rules (unconditional)

### Errors

- **Library/daemon crates:** one `thiserror::Error` enum covering the crate's
  fallible public surface. Behavior callers branch on (exit codes, HTTP status,
  retry-ability) lives as a **method on the error type**, never as message text.
- **Binary edges** (`main`, leaf orchestration): `anyhow` with `.context()`.
  `bail!` for early error exits.
- **Never `Result<T, String>`.** It erases exactly what callers branch on and
  forces substring-matching downstream — `hark`'s router picks HTTP statuses
  with `e.contains("already exists")`, one rewording from silent breakage.
  The same repo's `nxm` `NxmError` (thiserror + `exit_code()`) is the fix.
- **No bare `.unwrap()` outside `#[cfg(test)]`.** Use `.expect("...")` where
  the message states the invariant that makes it unreachable ("clap guarantees
  content when --file is absent"). Public fns that can panic get a `# Panics`
  doc section; fallible public fns get `# Errors`.
- **Log full chains.** `tracing::error!(error = %err)` shows only the outermost
  context. Use a `chain()` helper (`format!("{err:#}")`) — template in
  `references/idioms.md`.

### Locks

- `parking_lot::Mutex` for synchronous guards — no poisoning, so
  `.lock().unwrap()` is impossible by construction rather than by discipline.
- A lock held across an `.await` must be `tokio::sync::Mutex` instead.
- If stuck with `std::sync::Mutex`, recover poison via
  `.lock().unwrap_or_else(std::sync::PoisonError::into_inner)` with a why-safe
  comment — in **one accessor**, not repeated at 15 call sites.

### Control flow

- `let-else` for extract-or-bail. If-let chains (`if let Some(a) = x && a > 0`)
  to flatten nesting — **edition 2024+ only**.
- Iterator chains (`filter_map`, `map`+`collect`) are the default; a `for` loop
  is correct when per-item `?` propagation would fight a closure.
- Match enums you own exhaustively — no `_ =>` catch-all; let the compiler find
  every match when a variant is added.

### Types & API surface

- Derive eagerly: `Debug`, `Clone`, `PartialEq`/`Eq`, `Default` (enums via a
  `#[default]` variant), serde as needed. Exception: types holding secrets get
  a manual redacting `Debug`.
- `#[must_use]` on pure computations. Struct fields private; `pub(crate)` by
  default; no wildcard imports.
- `impl Trait` / generics over `Box<dyn Trait>` unless you genuinely need
  dynamic dispatch — the single most common agent-written-Rust failure.
- Newtype domain identifiers once they cross function boundaries (`DeviceName`,
  not `String`). Small programs may defer; say so consciously.
- Constructors are `Foo::new`; conversions are `From`/`TryFrom`/`AsRef` impls,
  not ad-hoc `.to_x()` methods. Builders (the `bon` derive) once a constructor
  passes ~4 params or goes optional-heavy.
- Full API depth (visibility, `#[non_exhaustive]`, sealed traits, doc-comment
  shape, consuming-`self`): read `references/api-design.md` when designing any
  public surface.

### Lints

- `[workspace.lints.clippy]` with `pedantic = { level = "warn", priority = -1 }`
  and `cognitive_complexity = "warn"`; the gate runs clippy with `-D warnings`
  (two-tier: warn for the IDE, deny in the gate).
- **Every `#[allow(clippy::...)]` carries a justification comment** stating why
  the suggested fix doesn't apply. A reasoned allow is a legitimate judgment
  call ("the single build assembly point; grouping would just rename the
  eight"); a bare allow is a silenced smell.

### Duplication

- Before writing a helper in one crate of a workspace, `rg` the siblings for
  it. Third copy = move it to a shared crate **and wire the dependency** — an
  unshipped shared crate with zero consumers fixes nothing.

### Files & functions

- ~400-line files, ~100-line functions (the bootstrap gate enforces these on
  new projects). Split by concern — a `main.rs` accreting seven subcommands'
  arg-handling wants submodules long before line 900.

### Unsafe & FFI

- **Reach for `rustix` before raw `libc`.** POSIX calls (uids, process info,
  fds, sockets) have safe wrappers — `rustix` is the house default. Raw
  `unsafe { libc::... }` is a last resort for what no wrapper crate covers.
- Every remaining `unsafe` block gets a `// SAFETY:` comment stating the upheld
  invariant; every `unsafe fn` gets a `# Safety` doc section. An agent editing
  later cannot infer an invariant nobody wrote down.

### Macros

Decision order: fixed shape and arity → **plain function/generic, no macro**;
pattern-based codegen over a fixed evocative shape → `macro_rules!`; needs
field/variant inspection → derive macro (check crates.io first — `bon`,
`thiserror`, `strum` likely already solve it); DSL or signature transform →
proc macro, reluctantly. Macro expansion is invisible to anyone reading
linearly — humans and agents both — so budget it like a readability cost.
Read `references/macros.md` before writing any `macro_rules!` or proc macro.

## Preferred libraries (mid-development reaches)

Scaffolding-time defaults (clap, serde, tokio, tracing, reqwest, jiff, uuid,
schemars, test crates) live in `bootstrapping-projects` → `references/rust.md`
— consult that table when adding a dep it covers. These are the style-driven
picks this skill adds, with the why; verify currency with `find-docs`/ctx7:

| Need | Reach for | Why it's policy |
|------|-----------|-----------------|
| POSIX calls (uids, fds, signals, process) | `rustix` | Safe wrappers; raw `unsafe { libc::... }` only for what no wrapper covers |
| Sync locks | `parking_lot` | No poisoning — deletes `.lock().unwrap()` structurally |
| Builders | `bon` | Compile-time-checked required fields; `typed-builder` = older equivalent; `derive_builder` = legacy, avoid |
| Error enums | `thiserror` | House style — do not claim it was "intentionally omitted" |
| Binary-edge errors | `anyhow` | `.context()` chains; render with `{err:#}` |
| Enum names/iteration/discriminants | `strum` | Beats hand-rolled `as_str()`/`from_str` tables |

## Gotchas (house-specific — read before assuming)

- **A `clippy.toml` threshold is dead config unless `[workspace.lints.clippy]`
  enables the lint it governs.** `cognitive-complexity-threshold = 30` with no
  `cognitive_complexity = "warn"` has never fired once — this is live in
  `lulu-tools` today and gives false confidence in review.
- **Let chains are edition-2024-gated** (stable since 1.88 but not on older
  editions). `gen` blocks are still unstable — don't suggest them. Async
  closures are stable — use them over the boxed-future-returning-closure shape.
- **The `async-trait` crate is only needed for `dyn` dispatch** — native
  `async fn` in traits works for static dispatch; don't add the dep otherwise.
- **`lulu-tools` has an in-flight `lulu-config` crate** (secret resolution,
  XDG paths) that is untracked with zero consumers. If working there, wiring it
  beats adding a 10th copy of `reset_sigpipe()` / key resolution.
- **Blanket pedantic is house policy for greenfield** (beam passes it clean at
  deny level) even though exemplar projects (ripgrep, jj, ruff) run default
  clippy and cherry-pick. On legacy code, cherry-picking is the ladder — see
  `references/brownfield.md` — not a reason to skip the end state.
- **Never invent project history to defend the status quo.** "We intentionally
  omitted thiserror" has been claimed in a session here and was false — the
  absence of a crate or pattern is not evidence of a decision. Check
  `git log`/`Cargo.toml` history or ask; thiserror and rustix are both house
  style, and both have had to be begged for against fabricated rationales.
- **serde config structs are fail-closed:** `#[serde(deny_unknown_fields)]` so
  a typo'd key rejects the file instead of silently widening behavior.

## Reference map (load on demand)

- `references/idioms.md` — worked templates: thiserror enum with `exit_code()`,
  the `chain()` tracing helper, expect-with-invariant, let-else/if-let-chain
  shapes, lock patterns. **Load when** writing error types, logging errors, or
  unsure how a rule looks in real code.
- `references/api-design.md` — derives, builders (`bon`), newtypes,
  conversions, visibility, future-proofing, doc-comment style. **Load when**
  designing or reviewing any public API surface.
- `references/macros.md` — the full decision tree, `macro_rules!` craft,
  readability budgeting, derive-first shopping list. **Load when** writing or
  reviewing any macro.
- `references/brownfield.md` — the lint-escalation ladder, boy-scout
  boundaries, structural-retrofit ordering, audit commands. **Load when**
  touching a repo that predates these rules or asked to "make it idiomatic".
