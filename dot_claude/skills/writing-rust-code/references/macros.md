# Macros

Load before writing or reviewing any `macro_rules!` or proc macro. The core
tension: macros buy expressiveness at the cost of **invisible expansion** — a
one-line invocation can hide hundreds of generated lines from anyone reading
linearly, human or agent (Effective Rust Item 28). Budget that cost like any
other readability cost.

## The decision tree

```text
Need code generation?
├─ Input shape AND arity are fixed        → plain function / generic. No macro.
├─ Pattern-based codegen, fixed evocative
│  input shape (variadic, repetitive)     → macro_rules!
├─ Needs struct/enum field inspection     → derive macro — but SHOP FIRST (below)
├─ Small DSL                              → function-like proc macro (reluctantly)
└─ Transforming a fn signature            → attribute proc macro (reluctantly)
```

The first branch is the one agents skip: if a function or a generic can express
it, the macro is pure cost. "I'd have to write the same three lines per type"
is a generics problem before it's a macro problem.

## Shop before writing a derive

The ecosystem has almost certainly already written the proc macro you're about
to. Check (via `find-docs`/ctx7 — not memory) before hand-rolling:

| Need | Existing derive |
|------|-----------------|
| Builders | `bon` (default), `typed-builder` |
| Error types | `thiserror` |
| Enum iteration / names / discriminants | `strum` |
| CLI args | `clap` (derive) |
| Ser/de | `serde`, `schemars` for JSON Schema |

A hand-written proc macro is a whole sub-crate with `syn`/`quote` deps, its own
compile-time cost, and a maintenance surface — it needs to earn all three.

## macro_rules! craft

- **Evocative input shape** (C-EVOCATIVE): the invocation should read like the
  Rust it expands to — `rules! { on url open "https://..." }` beats an
  arg-soup the reader must decode against the macro def.
- **Works everywhere** (C-ANYWHERE): expansion shouldn't assume it's inside a
  fn, a module, or a specific crate's `use` graph. `$crate::` paths, absolute
  `::std::` paths in expansions.
- **Respect visibility syntax** (C-MACRO-VIS): if it generates items, accept
  `pub` the way normal items spell it.
- Keep the rule set small. A `macro_rules!` with six arms and recursive munching
  is a proc macro wearing a disguise — and the worst of both worlds to debug.
- **Document what it expands to.** The macro's doc comment shows one concrete
  invocation and the code it generates. This is the `// SAFETY:` analog for
  macros: the reader (and the next agent) cannot see the expansion, so write it
  down. `cargo expand` output is the source for keeping that honest.

## Good defaults are the point

The macro pattern that *helps* readability is the boring one: a derive with
sensible defaults and per-field attribute overrides —

```rust
#[derive(bon::Builder)]
pub struct SynthArgs {
  voice: String,
  #[builder(default = 1.0)]
  speed: f32,
  #[builder(default)]
  stream: bool,
}
```

Guessable, greppable, locally readable — the reader predicts the expansion
without looking. The macro pattern that hurts is the clever one: a DSL whose
semantics live only in the macro definition. When both would work, boring wins.

## The trait-impl one-liner (idiomatic, dev-friendly)

When a library trait's impl is pure boilerplate (assoc consts + nothing else),
export a `macro_rules!` from the library that writes it — with the default
pulled from use-site context and an override arity for the deviating case:

```rust
// in the library crate
#[macro_export]
macro_rules! impl_config {
  ($ty:ty) => {
    // env! expands at the USE site → the consuming crate's own name
    $crate::impl_config!($ty, env!("CARGO_PKG_NAME"));
  };
  ($ty:ty, $tool:expr) => {
    impl $crate::LuluConfig for $ty {
      const TOOL: &'static str = $tool;
    }
  };
}

// consumers
lulu_config::impl_config!(Config);           // tool = crate name (sane default)
lulu_config::impl_config!(Config, "image");  // imager's binary name deviates
```

Why this is the house shape: zero-ceremony default, one obvious override seam,
no proc-macro sub-crate (no syn/quote, no extra compile cost), and the
expansion is a three-line impl anyone can predict. Escalate to a
`#[derive(...)]` with helper attributes only when the trait grows enough
configuration that positional args stop reading clearly.

## Testing

- Derive/attribute macros: `trybuild` for compile-pass/compile-fail cases —
  the failure *messages* are part of the macro's API.
- `macro_rules!`: ordinary unit tests on the expanded behavior are usually
  enough; add a `cargo expand` snippet to the doc comment when the expansion
  is non-obvious.
