# API design

Load when designing or reviewing any public surface — a crate API, a module's
`pub` items, or a type other code will hold. Distilled from the Rust API
Guidelines (the C- rules that matter at this scale), Effective Rust, and the
house codebases.

## Derives (C-COMMON-TRAITS)

Derive eagerly on every public type unless there's a stated reason not to:
`Debug`, `Clone`, `PartialEq`/`Eq`, `Hash` where it keys maps, `Default`,
`Serialize`/`Deserialize` where it crosses a boundary, `PartialOrd`/`Ord` where
ordering is meaningful.

- Enums derive `Default` via a `#[default]` variant attribute — never a
  hand-written `impl Default` that restates one variant.
- **Secrets exception:** types holding tokens/keys get a manual `Debug` that
  redacts (`.field("token", &"<redacted>")`) — an eager derive here is a leak.
- Don't duplicate derive bounds on the struct declaration itself
  (C-STRUCT-BOUNDS) — `#[derive(Clone)] struct Foo<T: Clone>` repeats what the
  derive already emits.

## Constructors, conversions, builders

- Constructors are static inherent methods — `Foo::new`, `Foo::with_root(...)`
  (C-CTOR). Not `Default::default()` contortions, not a `From` impl doing a
  constructor's job.
- Conversions are trait impls: `From`/`TryFrom` for owned, `AsRef`/`AsMut` for
  borrowed views (C-CONV-TRAITS). An ad-hoc `.to_x()` method duplicates what a
  `From` impl gives every caller for free (`.into()`, `?` coercion, generic
  bounds).
- Naming for the hand-written ones: `as_` (cheap borrow), `to_` (expensive
  copy), `into_` (consuming) — C-CONV.
- **Builder once a constructor passes ~4 params or goes optional-heavy**
  (C-BUILDER). Default to the **`bon`** derive — compile-time-checked required
  fields, active development. `typed-builder` is the battle-tested equivalent;
  `derive_builder` (runtime `Result`) is legacy — don't pick it for new code.
  Hand-roll only when the builder needs real logic between `set` and `build`.

## Newtypes (C-NEWTYPE)

Wrap a primitive once it carries domain meaning across function boundaries:

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct DeviceName(String);
```

What it buys: swapped-argument bugs become type errors; the impl block becomes
the one home for that concept's operations; the inner representation can change
without touching callers (C-NEWTYPE-HIDE).

Calibration: a small binary passing `target: &str` between three functions may
reasonably defer — but that's a *stated* choice, and it expires as call sites
multiply. `beam` defers consciously and documents each string's meaning;
that's the acceptable floor, not the ideal.

## Visibility & structure

- `pub(crate)` is the default; `pub` is a decision. Every public item is API
  you maintain and an agent's search space — minimize both.
- Struct fields private (C-STRUCT-PRIVATE); expose via methods. The impl block
  becomes the single place a reader finds the real surface.
- No wildcard imports — explicit imports keep every symbol greppable.
- `impl Trait` in argument and return position over `Box<dyn Trait>` unless
  you need dynamic dispatch or heterogeneous storage. Generic bounds over
  concrete types where the fn only needs a capability (`R: Read`, not `File`)
  — C-GENERIC, C-RW-VALUE.
- One-shot resources consume `self` in the terminal method (`fn run(self)`) —
  "don't call this twice" becomes unrepresentable instead of a comment
  (ripgrep's `Searcher` pattern).

## Traits many crates will implement

Minimize the required surface: associated consts (or one required method) for
what varies per implementor; **provided methods for all shared behavior**
(Effective Rust Item 13). The whole impl should be a handful of lines:

```rust
// consumer crate — this is the ENTIRE integration
impl lulu_config::LuluConfig for Config {
  const TOOL: &'static str = "speak";
}
// Config::load(), Config::config_path(), Config::schema() all provided
```

The anti-pattern this replaces (caught at lulu-config plan review): every
consumer hand-wiring engine calls in its own wrapper —
`lulu_config::load::load::<Config>("speak")` per crate — where the type, the
string, and the wiring can each drift independently. Data the provided methods
need comes from the assoc const (`Self::TOOL`), never from a parameter the
caller re-supplies at every call site.

## Future-proofing

- `#[non_exhaustive]` on public enums and config-like structs that will grow —
  downstream `match`es then require `_`, so adding a variant isn't semver-major.
  (Corollary: *within* the owning crate, keep matches exhaustive.)
- Sealed traits when downstream impls would constrain your evolution:

```rust
mod sealed { pub trait Sealed {} }
pub trait Backend: sealed::Sealed { ... }
```

- `#[must_use]` on pure computations and on types representing unfinished work
  (guards, builders, futures-adjacent handles).

## Doc comments (RFC 1574 / jj style)

```rust
/// Sends the envelope to every online peer matching the target.
///
/// Peers are resolved via the tailnet at call time; offline peers are skipped
/// and recorded in the ledger as `skipped:offline`.
///
/// # Errors
/// Returns an error when the tailnet is unreachable or the ledger write fails.
pub fn send(&self, envelope: Envelope) -> Result<Receipt> { ... }
```

- One-sentence, present-tense, third-person summary line. Blank line. Prose.
- `# Errors` on fallible pub fns, `# Panics` where a panic is possible,
  `# Safety` on `unsafe fn`.
- Rustdoc examples use `?`, not `.unwrap()` (C-QUESTION-MARK) — examples get
  copy-pasted, and they teach the error posture along with the API.
- Proper nouns that clippy's `doc_markdown` flags go in `clippy.toml`'s
  `doc-valid-idents`, not in backticks-to-shut-it-up.

## serde surfaces

- Config/rules structs: `#[serde(deny_unknown_fields)]` — a typo'd key rejects
  the file loudly instead of silently widening behavior. Test the rejection.
- Wire formats meant to be forward-compatible are the exception — there,
  unknown fields must be tolerated; say which posture a struct has.
