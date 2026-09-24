---
name: writing-ruby-code
description: >-
  Writes idiomatic, readable, modern Ruby (3.2 through 4.0) that is clear, easy
  to test, and type-checkable with Sorbet. Use whenever writing, editing,
  reviewing, or refactoring Ruby — any .rb, .rake, .gemspec, Gemfile, Rails, or
  RSpec file. Covers Sorbet typing strategy (sigil levels, when a sig earns its
  place, T::Struct vs Data.define), modern Ruby 3.x/4.0 syntax with per-feature
  version gates (pattern matching, endless methods, hash shorthand, anonymous
  forwarding, `it`), object design for testability (dependency injection,
  keyword args, seams), RSpec canon including the instance_double-vs-
  sorbet-runtime collision, the Shopify style guide deltas worth keeping, and
  the rubyfmt/RuboCop/ruby-lsp split of who owns which decision. Triggers on
  "idiomatic Ruby", "add types to this", "write a sig", "clean up this Ruby",
  "is this testable", RSpec design, rubocop config questions, or reviewing any
  Ruby diff.
---

# Writing Ruby Code

Idiomatic modern Ruby, optimized for three properties that are **the same
discipline wearing three hats: clear, testable, type-checkable.**

That is the organizing claim of this skill, not a slogan. What makes a Ruby
object type-checkable — explicit interfaces, a constructor that takes its
collaborators, data separated from behavior — is what makes it testable without
`allow_any_instance_of`, and what makes it readable. Every trick that defeats
Sorbet (`method_missing`, untyped hash-shaped "options", singletons reached for
at call time, monkeypatched core classes) defeats a unit test and a reader too.
So a rule that looks like it serves one axis is usually paying for all three.

Grounded in: Shopify's Ruby Style Guide (the house baseline, read in full), the
`rubocop-shopify` gem's *actual* cop config (which says something different from
its prose — see Gotchas), `editorder`'s live conventions in
`.claude/rules/ruby/`, and behavior verified by running Ruby 4.0.6 and rubyfmt
0.14.1 locally rather than recalling what they do.

This skill owns **how the code reads and how it is typed**. Project scaffolding
and the quality gate belong to `bootstrapping-projects`; commit messages to
`writing-git-commits`. Don't restate them, route to them.

## Step 0 — pin the Ruby version before writing a line

This is the single highest-frequency failure mode for Ruby written by an agent
on this machine, because **the dev box and the main work repo are four years
apart.** `ruby -v` here reports 4.0.6; `editorder/.ruby-version` says 3.2.2.
Code that runs fine in your scratch buffer is a `SyntaxError` in the repo.

Check, in this order, and believe the first one you find:

```sh
cat .ruby-version            # most repos
rg '^ruby ' .tool-versions mise.toml   # mise/asdf repos
rg 'required_ruby_version' *.gemspec   # gems — this is the real floor
rg -n 'TargetRubyVersion' .rubocop.yml
```

Feature floor (each needs *at least* this version):

| Feature | Floor | Notes |
|---|---|---|
| Pattern matching `case/in`, find pattern | 3.0 | stable in 3.0, experimental in 2.7 |
| Endless method `def x = expr` | 3.0 | args without parens from 3.1 |
| `Hash#except`, `...` full forwarding | 3.0 | |
| Hash shorthand `{x:, y:}` | **3.1** | the one that bites most often |
| Anonymous block forwarding `def f(&)` | **3.1** | |
| `Data.define` | **3.2** | `Struct(keyword_init:)` is redundant from 3.2 |
| Anonymous `*` / `**` forwarding | **3.2** | |
| `it` implicit block param | **3.4** | `_1` is the 3.0 fallback |
| `Set` without `require "set"` | **3.2** | autoloaded since 3.2; 4.0 reimplemented it in C |

For a 3.2.2 repo that means: pattern matching, hash shorthand, `Data.define`,
anonymous forwarding, bare `Set` — **yes**. `it` — **no**, use `_1`.

Ruby never shipped a 3.5; 3.4.x went straight to 4.0.0 (2025-12-25). Current
stable is 4.0.7. Don't write "Ruby 3.5" anywhere.

## The two postures (decide this second)

- **Writing new code — any repo, however messy.** Every rule below applies at
  full strength. A new method in an untyped legacy file still gets keyword
  args, a guard clause, and injected collaborators. The surrounding file's
  style is not a license.
- **Touching existing code.** Boy-scout rule with hard boundaries: raise what
  you touch, never rewrite the neighborhood. Raising a file's sigil from
  `# typed: false` to `true`, or a "make it idiomatic" sweep, is its own
  deliberate task — read `references/brownfield.md` before starting one, and
  before proposing one uninvited.

## Core rules

### Types — Sorbet is the default

- **Every new file gets `# typed: true`.** Not `false`. `false` checks only
  syntax and constant resolution — method bodies are never checked against
  sigs, so a `false` file with sigs is a hole that looks typed.
- **`# typed: strict` for new library/service objects** — it forces a `sig` on
  every method and a `T.let` on every ivar, which is exactly the discipline
  that makes the object testable. `editorder` sits at 532 strict / 1182 true /
  159 false / **0 strong**; strict is normal there, `strong` isn't a target.
- **Where a `sig` earns its place:** methods returning primitives, core
  classes, or app models/services; anything crossing an object boundary.
  **Where it doesn't:** Rails controller actions. `editorder`'s live rule.
- **`T::Struct` for a hash with known keys** — data, *never* behavior, named
  for the thing (`ShippingAddressStruct`), never `Data` or `Value`. **Avoid
  Sorbet shapes** (`T::Hash[Symbol, T.untyped]` standing in for a record):
  they type-check nothing and read worse than the struct.
- **`T.must`/`T.cast`/`T.unsafe` are assertions, not noise to silence a
  checker** — and `T.cast` does **zero** runtime checking, so a wrong one
  fails somewhere far away. Prefer restructuring so the nil can't arrive (a
  guard clause, a `fetch`) over asserting it away. If you use `T.unsafe`, the
  line above says why.
- Depth — `T::Enum`, `abstract!`/`interface!`, generics, the strict-mode
  memoization idiom, Tapioca, the RBS question: `references/sorbet.md`.

### Object design — the testability axis

- **Take collaborators in the constructor; don't reach for them.** A class that
  calls `SomeClient.new` inside a method can only be tested by stubbing a
  constant. The same class taking `client:` can be tested with a real fake and
  type-checked with an interface. This one rule buys more than the rest of the
  section combined.
- **Keyword arguments over an options hash**, always. They are self-documenting
  at the call site, `sig`-able one by one, and Ruby 3 checks arity for you. A
  positional boolean (`process(order, true)`) is a defect waiting to happen.
- **Prefer modules to classes that hold only class methods** — instances that
  can't be instantiated are a smell. When a module really is a namespace of
  functions, `extend self` (Shopify's pick over `module_function`).
- **Separate data from behavior.** `Data.define` (3.2+) for immutable value
  objects, `T::Struct` when it must be Sorbet-typed, `Struct` only when you
  genuinely need mutation or positional access. A value object with no methods
  is a feature.
- Avoid `method_missing`, `define_method` over dynamic names, and monkeypatching
  core classes. Each one deletes a type, a test seam, and a grep result at once.

### Modern syntax defaults (gated on Step 0)

Worked examples and the full ladder in `references/modern-ruby.md`.

- **Hash shorthand `{x:, y:}`** whenever the key matches the local name. House
  policy at `editorder`, and it is **valid Ruby** — agents have flagged it as a
  syntax error here before. It is not one.
- **Endless methods** for a single side-effect-free expression:
  `def admin? = role == "admin"`. Never `initialize`, never a multi-line body.
- **Pattern matching** for structural destructuring — API payloads, config
  blobs, anything you'd otherwise pick apart with a `dig`/`fetch` chain. Give
  your own objects `deconstruct_keys` rather than exposing a hash.
- **Anonymous forwarding** in wrappers: `def f(&) = g(&)`,
  `def f(*, **) = g(*, **)`. (But `editorder` sets
  `Naming/BlockForwarding: explicit` — follow the repo.)
- **`it` over `_1`** for a trivial one-argument block on 3.4+; a named
  parameter for anything longer.
- **`Hash#except`, `tally`, `filter_map`, `clamp`, `then`** over the
  hand-rolled equivalents.
- **`# frozen_string_literal: true` on every file**, blank line after it.
  Still required in 4.0 — verified: literals are *chilled*, not frozen, and
  mutation only warns under `-W:deprecated`.

### Style — the parts that aren't mechanical

Full rules in `references/style.md`; rubyfmt already owns everything about
whitespace. These are the ones with teeth:

- **`class << self`, grouped in one block** — not scattered `def self.foo`.
  Concrete reason: `private` does **not** apply to a `def self.` below it, so
  the scattered form ships public methods you believed were private.
- **`Hash#fetch` when a key must exist.** `[]` returns `nil` on a typo and you
  find out three frames later. `fetch(key, default)` for defaults, because
  `hash[key] || default` is wrong when the value is legitimately `false`.
- **`raise SomeError, "message"`** — two arguments. The instance form can't
  take a backtrace as a third. `raise "msg"` is already a `RuntimeError`.
- **Never `rescue Exception`** (catches signals and `SystemExit`); a bare
  `rescue` means `StandardError`, which is what you want. No empty `rescue`,
  no `rescue nil` modifier — it swallows typos alongside the real error.
- **Never `return` from an `ensure` block or a memoized `begin`** — both
  silently discard what they were wrapping. (`Lint/NoReturnInMemoization` is
  one of only two custom cops `rubocop-shopify` ships, which says how often
  this bites.)
- Name the rescue variable `error`, not `e`, and **delete an unused one**
  rather than writing `=> _e`.
- **`\A`/`\z`, never `^`/`$`**, when anchoring a whole string — `^`/`$` match
  line boundaries, which is a real injection vector.
- **`||=` never for booleans.** `@enabled ||= true` overwrites a deliberate
  `false`. Use `@enabled = true if @enabled.nil?`.
- `public_send` over `send`; guard clauses over nesting (three levels of block
  nesting is the ceiling); predicates end in `?` and return a boolean, with no
  `is_`/`get_` prefix.
- Don't write `class A::B` — constant lookup won't search `A`, so a constant
  defined there raises `NameError` inside `B`. Nest the modules.
### Formatting & lints — who owns which decision

This split is the part agents get wrong, so it is explicit:

| Decision | Owner |
|---|---|
| Indentation, brace spacing, chain layout, `if`-assignment shape, quote style | **rubyfmt** — run it, don't argue |
| **Where lines break** | **You.** rubyfmt does not wrap (verified — it left a 115-char line alone and has no width flag) |
| Max line length (**100 here**) | **RuboCop** `Layout/LineLength: Max: 100` |
| Semantics: `fetch` vs `[]`, `class << self`, dead code, Ruby-3 cops | **RuboCop** |
| Types | **`srb tc`** |
| Editor plumbing | **ruby-lsp** |

- Format with `rubyfmt -i <path>`; `rubyfmt -c` for a check-mode diff in CI.
- **`Layout/LineLength` must be set by you.** `rubocop-shopify` disables the cop
  outright, and the prose guide's 120 is not enforced anywhere. 100 is the house
  number; write it into `.rubocop.yml` explicitly or you get no limit at all.
- Config templates (`.rubocop.yml` with `inherit_gem`, the `rubocop-rubyfmt`
  pairing, sorbet/tapioca CI steps, ruby-lsp settings): `references/tooling.md`.

### Testing

RSpec, `expect` syntax only. The full canon — `let` vs `let!`, verifying
doubles, shared examples, the FactoryBot and VCR rules from `editorder`, and the
**`instance_double` × `sorbet-runtime` collision that makes typed code fail its
own specs** — is in `references/testing.md`. Read it before writing specs for
anything that has `sig`s; the collision is not guessable.

## Preferred libraries

Verify currency with `find-docs`/ctx7 before pinning. Versions confirmed
2026-09-21.

| Need | Reach for | Version | Why |
|---|---|---|---|
| Static types | `sorbet` + `sorbet-runtime` | 0.6.13506 | House default; mature tooling, real editor support |
| RBI generation | `tapioca` | 0.20.0 | `tapioca gems` + `tapioca dsl`; `--verify` is the CI gate |
| Formatting | `rubyfmt` | 0.14.x | **Homebrew binary, not a gem** — see Gotchas |
| Lint config | `rubocop-shopify` | 3.1.0 | `inherit_gem`, then override `Layout/LineLength` |
| rubyfmt ↔ RuboCop peace | `rubocop-rubyfmt` | 0.1.2 | Disables the Layout cops that fight the formatter |
| Sorbet cops | `rubocop-sorbet` | 0.16.0 | Sigil/sig hygiene |
| RSpec cops | `rubocop-rspec` | 3.10.2 | |
| Tests | `rspec` | 3.13.x | There is no RSpec 4 — don't pin `~> 4` |
| Doubles under Sorbet | `rspec-sorbet` | 1.9.2 | Load-bearing but stale — see Gotchas |
| Editor | `ruby-lsp` | 0.26.11 | 0.27 is beta; `ruby-lsp-rails`, `ruby-lsp-rspec` exist |

## Gotchas (verified — read before assuming)

- **rubyfmt deletes trailing commas.** The Shopify prose guide mandates a
  trailing comma in multi-line collection literals; rubyfmt strips them (I fed
  it `from: "b",` and got `from: "b"` back). `rubocop-shopify` disables all
  three `TrailingComma` cops, so nothing enforces the guide's rule either.
  **Don't add trailing commas** — the formatter will churn them out on save.
- **rubyfmt contradicts the guide on lambdas too.** The guide says `->(x, y)`
  and calls `-> (x, y)` bad; rubyfmt *adds* that space. The formatter wins;
  don't hand-fix it back.
- **rubyfmt does not wrap long lines and has no width flag.** A 115-char line
  passes through untouched. Line-breaking is a human/agent decision that
  `Layout/LineLength` polices after the fact — the formatter will not save you.
- **rubyfmt is not a gem.** It is a Rust binary from Homebrew (`brew install
  rubyfmt`), and the `rubyfmt` *gem* on rubygems.org is an unrelated abandoned
  2014 project. Never add it to a Gemfile. CI needs the binary installed.
  Upstream is maintained under an explicit "no lead maintainer" model — last
  commit 2026-08-10, steady contributor cadence, not abandoned but not thriving.
- **ruby-lsp will not pick rubyfmt on its own.** `rubyLsp.formatter: "auto"`
  resolves to RuboCop if it's in the bundle, else `syntax_tree`, else nothing —
  rubyfmt is not first-party. Wire it as an editor/hook formatter explicitly
  (`editorder` does this through `./bin/setup-claude`, not through the LSP).
- **`rubocop-shopify` deliberately stopped enforcing style.** In "The great
  reset" (PR #687, Feb 2025) Shopify disabled nearly every cop on purpose —
  the stated reasoning was that mandatory parens, forced method choices, and
  trailing commas were "causing Ruby programs that felt not really like Ruby."
  The gem is now a **correctness linter, not a style enforcer**: 384 cops off,
  37 on. `Layout/LineLength`, `StringLiterals`, every `TrailingComma`,
  `BlockDelimiters`, and all `Metrics/*` are **off**, so "the Shopify guide
  says 120 characters / limit method length" is not something any tool checks.
  The survivors are semantic and notably modern (`Style/EndlessMethod`,
  `Lint/DataDefineOverride`, `Lint/UnreachablePatternBranch`,
  `Style/TallyMethod`). Read the YAML, not the prose.
- **The prose guide has zero Ruby 3 content, and is frozen.** Its newest
  feature is the 2.3 squiggly heredoc, and its last substantive prose edit
  was 2022-2023 — the only 2025 touch was an Eleventy→Jekyll migration.
  It never mentions pattern matching, `Data.define`, hash
  shorthand, anonymous forwarding, or `it` — and it recommends **Minitest**,
  which is not what this house uses. Treat its Testing section as out of scope
  and everything else as a pre-3.0 baseline this skill layers on top of.
- **`rspec-sorbet` is load-bearing and four years stale** (1.9.2, last released
  2023-03-24, 8.5M downloads). Without `RSpec::Sorbet.allow_doubles!` in
  `spec_helper.rb`, `instance_double` raises a `TypeError` against any `sig`'d
  parameter at runtime. `editorder` does *not* use it and routes around the
  problem by mocking at the HTTP boundary instead — see `references/testing.md`
  for which of the two to pick.
- **Two `T::Struct` instances with identical attributes are not `==`.** The `eq`
  matcher will fail in a way that reads like a data bug. `Data.define` objects
  *do* compare by value — one more reason to prefer them where Sorbet isn't
  demanding a `T::Struct`.
- **Ruby 4.0's one grammar change can break `srb tc`.** 4.0 is a
  30th-anniversary version number, not a breaking rewrite — the only new syntax
  is that a line starting with `&&`, `||`, `and`, or `or` now continues the
  previous line. Sorbet choked on exactly that
  ([sorbet/sorbet#10589](https://github.com/sorbet/sorbet/issues/10589), closed
  2026-08-26 with no linked commit, so the fix is unconfirmed). If you write
  leading-operator continuations in a Sorbet-checked file, run `srb tc` before
  believing it. Sorbet deliberately does not warn about newer-Ruby syntax at
  all — it delegates that to RuboCop.
- **Prism has been the default parser since 3.4, not 4.0.** rubyfmt, ruby-lsp,
  and RuboCop 1.91 all parse through it, which is why they handle 4.0 syntax
  without per-version releases. Don't describe Prism as a 4.0 feature.
- **`rubocop-shopify` sets `NewCops: disable` and no `TargetRubyVersion`.** New
  cops are opt-in by design, and the Ruby target comes from *your* repo's
  `.ruby-version`/gemspec. Inheriting the gem does not pin a Ruby version for
  you.
- **Don't invent project history to justify the status quo.** The absence of
  `rubocop-shopify` from a Gemfile is not evidence someone rejected it. Check
  `git log` or ask.

## Reference map (load on demand)

- `references/modern-ruby.md` — the 3.0→4.0 feature ladder with a worked
  example and version gate for each, plus what 3.x deprecated. **Load when**
  choosing between a modern form and a classic one, or targeting an older Ruby.
- `references/sorbet.md` — sigil levels, `sig` grammar, `T::Struct`/`T::Enum`,
  abstract/interface, generics, Tapioca + RBI workflow, the RBS question.
  **Load when** adding types, raising a sigil, or debugging `srb tc`.
- `references/testing.md` — RSpec canon, verifying doubles, the
  `instance_double` × `sorbet-runtime` collision and both fixes, FactoryBot and
  VCR rules. **Load when** writing or reviewing any spec.
- `references/style.md` — the Shopify layout/syntax/naming rules worth keeping,
  annotated with which ones rubyfmt already handles and which are yours.
  **Load when** a formatting or naming question isn't settled by running rubyfmt.
- `references/tooling.md` — copy-pasteable `.rubocop.yml`, `sorbet/config`,
  `.rspec`, ruby-lsp settings, CI steps, and the command cheat-sheet.
  **Load when** wiring a repo or fixing a tool fight.
- `references/brownfield.md` — sigil-raising ladder, boy-scout boundaries,
  retrofit ordering, audit commands. **Load when** touching an untyped or
  pre-3.0 codebase, or asked to "make it idiomatic".
