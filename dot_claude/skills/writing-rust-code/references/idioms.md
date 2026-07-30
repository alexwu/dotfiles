# Idioms: errors, control flow, locks — worked templates

Load when writing error types, logging errors, or unsure how a core rule looks
in real code. Templates are drawn from `lulu-agent`, `beam`, and `nxm` (the
clean corners of the house codebases).

## Error types

### The decision table

| Surface | Shape |
|---------|-------|
| Library / daemon crate's public fallible API | One `thiserror::Error` enum per crate |
| Binary `main` + leaf orchestration | `anyhow::Result` + `.context()` / `bail!` |
| Anything | **Never `Result<T, String>`** |

### thiserror enum with behavior as a method

Callers branch on error *kind* — exit codes, HTTP status, retry-ability. That
mapping is a method on the type, so it can't drift from the messages:

```rust
#[derive(Debug, thiserror::Error)]
pub enum WatchError {
  #[error("watch `{0}` already exists")]
  AlreadyExists(String),
  #[error("no watch named `{0}`")]
  NotFound(String),
  #[error("store: {0}")]
  Store(#[from] rusqlite::Error),
}

impl WatchError {
  pub fn http_status(&self) -> StatusCode {
    match self {
      Self::AlreadyExists(_) => StatusCode::CONFLICT,
      Self::NotFound(_) => StatusCode::NOT_FOUND,
      Self::Store(_) => StatusCode::INTERNAL_SERVER_ERROR,
    }
  }
}
```

The cautionary example this replaces (live in `hark`'s router today):

```rust
// DON'T — one message rewording silently breaks the status mapping
if e.contains("already exists") { StatusCode::CONFLICT }
else if e.contains("no watch named") { StatusCode::NOT_FOUND }
else { StatusCode::INTERNAL_SERVER_ERROR }
```

For CLIs, the same pattern with `exit_code() -> u8` (see
`lulu-tools/crates/nxm/src/auth.rs` — `NxmError`).

### Doc sections

Every fallible pub fn:

```rust
/// Loads the rules file, applying defaults for absent optional fields.
///
/// # Errors
/// Returns an error when the file is unreadable, is not valid TOML, or
/// contains an unknown key (`deny_unknown_fields` — fail closed).
pub fn load(path: &Path) -> Result<RulesFile> { ... }
```

`# Panics` on any pub fn that can panic — which should mean "carries an
`.expect()` whose invariant is stated there."

### expect-with-invariant

```rust
// clap's `required_unless_present("file")` makes this unreachable
let content = content.expect("clap guarantees content when --file is absent");
```

The message is the *invariant*, not a restatement of the failure ("failed to
get content" says nothing). Bare `.unwrap()` only inside `#[cfg(test)]`.

### Logging the full chain

`error = %err` renders only the outermost `.context()` layer. House pattern —
a tiny helper, used at every `tracing::error!`/`warn!` site:

```rust
/// Renders the full anyhow cause chain on one line for tracing fields.
/// `{err:#}` = "outermost: middle: root cause".
pub fn chain(err: &anyhow::Error) -> String {
  format!("{err:#}")
}

tracing::error!(error = %chain(&err), url = %url, "relay poke failed");
```

(Born from a real production log line that showed the URL but hid the
connection-refused underneath.)

## Control flow

### let-else: extract or bail

```rust
let Some(home) = std::env::var_os("HOME") else {
  bail!("HOME is unset");
};
```

One level of nesting gone, the happy path stays left-aligned. Use it any time
the else-arm diverges (return/bail/continue/break).

### if-let chains (edition 2024+ only)

```rust
if let Some(copy) = &state.blob_copy
  && copy.handle.is_finished()
  && let Some(result) = copy.take_result()
{
  ...
}
```

Flattens what used to be a pyramid. **Check the crate's edition first** — the
feature is stable (1.88) but gated to edition 2024.

### Iterators vs loops

Chains are the default:

```rust
let names: Vec<_> = peers.iter()
  .filter(|p| p.online)
  .map(|p| p.dns_name.trim_end_matches('.'))
  .collect();
```

A `for` loop is the *better* choice when each item's processing is fallible and
`?` needs to propagate — a `?` inside `map()` fights the closure's return type:

```rust
// rusqlite rows: Result per row; `?` propagates cleanly in a for loop
for row in rows {
  let entry = row?;
  out.push(parse_entry(entry)?);
}
```

Don't contort into `.map(...).collect::<Result<Vec<_>, _>>()` when the loop
reads better — the rule is readability, not iterator maximalism.

### Exhaustive matches

On enums you own, list every variant. A `_ =>` arm converts "compiler finds
every match site when a variant is added" into a silent fallthrough bug.
`_` is fine on non-exhaustive foreign enums, where it's forced anyway.

## Locks

| Situation | Tool |
|-----------|------|
| Sync guard, never held across `.await` | `parking_lot::Mutex` |
| Guard held across `.await` | `tokio::sync::Mutex` |
| Stuck with `std::sync::Mutex` | poison-recovery accessor, once |

`parking_lot::Mutex::lock()` returns the guard directly — no `Result`, no
poisoning, nothing to unwrap. This deletes the `.lock().unwrap()` pattern
structurally (`lulu-agent`'s daemon registry is the template) instead of
policing it per call site (`hark`'s supervisor repeats it 18 times).

If std must stay:

```rust
/// Sub-ms single-row writes, never held across .await — a panic mid-write
/// leaves no torn state worth failing over, so recover the poison.
fn ledger(&self) -> std::sync::MutexGuard<'_, Ledger> {
  self.ledger.lock().unwrap_or_else(std::sync::PoisonError::into_inner)
}
```

One accessor, with the why-safe reasoning — not 15 inline copies.

## Async odds and ends

- Async closures (`async || { ... }`) are stable — use them with the
  `AsyncFn`/`AsyncFnMut`/`AsyncFnOnce` bounds instead of the old
  `F: Fn() -> Fut, Fut: Future<Output = T>` double-generic.
- Native `async fn` in traits covers static dispatch. Add the `async-trait`
  crate only when you need `dyn` — and note `Send` bounds don't auto-propagate;
  assert them in a test if a spawn requires them.
