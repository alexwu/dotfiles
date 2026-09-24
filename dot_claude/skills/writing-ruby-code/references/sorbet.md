# Sorbet

Sorbet is the house type-checker. Versions confirmed 2026-09-21:
`sorbet`/`sorbet-runtime` 0.6.13506 (released daily), `tapioca` 0.20.0.

## Sigil levels

Each level is a superset of the one below. The sigil goes on line 1, above
`# frozen_string_literal: true`.

| Sigil | Checks | Use it for |
|---|---|---|
| `ignore` | nothing — not even parsed | generated files, vendored code |
| `false` | syntax + constant resolution only. **Method bodies are not checked against sigs.** | legacy files you haven't raised yet |
| `true` | full checking inside the file; sigs enforced at call sites | **the floor for every new file** |
| `strict` | + every method needs a `sig`, every ivar needs a `T.let` | new service/library objects |
| `strong` | + no `T.untyped` anywhere | not a realistic target — `editorder` has zero |

`editorder`'s live distribution: 1182 `true`, 532 `strict`, 159 `false`, 0
`strong`. Strict is normal there, not aspirational.

The trap is `# typed: false`. It looks typed to a reader and checks nothing
inside a method body. A file that has sigs but sits at `false` is worse than an
honest untyped file, because the sigs imply a guarantee nobody is enforcing.

## The shape of a typed class

House style, taken from `editorder`'s strict services:

```ruby
# typed: strict
# frozen_string_literal: true

class UpdateScopesService
  extend T::Sig

  class Result < T::Struct
    const :return_path, String
    const :scope_provider, String
  end

  sig { returns(Shop) }
  attr_reader :shop

  sig { params(shop: Shop, params: ActionController::Parameters).void }
  def initialize(shop, params)
    @shop = shop
    @params = params
  end

  sig { returns(Result) }
  def call
    Result.new(return_path: return_path, scope_provider: scope_provider)
  end
end
```

`extend T::Sig` goes inside the class, not at the top of the file. `attr_reader`
takes a `sig { returns(...) }` of its own.

## Where a sig earns its place

- **Yes:** methods returning primitives, core classes, or app models/services;
  anything crossing an object boundary; every method in a `strict` file
  (mandatory).
- **No:** Rails controller actions. They're routed, they render or redirect,
  and their return value is meaningless. `editorder` codifies this.

## `sig` grammar you'll actually use

```ruby
sig { params(x: Integer, name: String).returns(String) }
sig { params(x: Integer).void }                      # no meaningful return
sig { returns(T.nilable(User)) }
sig { params(items: T::Array[String]).returns(T::Hash[Symbol, Integer]) }
sig { params(blk: T.proc.params(u: User).void).void }
sig { abstract.params(food: Food).void }
sig { override.params(food: Food).void }
sig { type_parameters(:U).params(x: T.type_parameter(:U)).returns(T.type_parameter(:U)) }
```

## Assertions — each one is a claim you're making

| Form | Runtime cost | What it means |
|---|---|---|
| `T.let(expr, Type)` | **checks** | "this is a `Type`" — required for ivars in `strict` |
| `T.must(expr)` | **checks** | "not nil" — raises `TypeError` if it is |
| `T.cast(expr, Type)` | **none** | "trust me" — a wrong cast fails somewhere far away |
| `T.unsafe(expr)` | none | turns the expression into `T.untyped` |
| `T.nilable(Type)` | — | sugar for `T.any(Type, NilClass)` |

`T.cast` and `T.unsafe` are `# typed: false` scoped to one expression. If you
use either, the line above says why. Prefer restructuring so the nil can't
arrive — a guard clause, a `fetch`, a non-nilable constructor — over asserting
it away with `T.must`.

## Memoization in a `strict` file

This is the ugliest thing in Sorbet and an agent will get it wrong. In
`strict`, every ivar needs a declared type, but a lazily-memoized ivar has no
assignment site to hang it on. The idiom:

```ruby
sig { returns(String) }
def version
  @version = T.let(@version, T.nilable(String))
  @version ||= expensive_lookup
end
```

The first line is a type declaration, not an assignment — it declares `@version`
as `T.nilable(String)` and leaves its value alone. It reads like a no-op and
isn't. Don't "clean it up."

## T::Struct and T::Enum

```ruby
class ShippingAddressStruct < T::Struct
  const :line_1, String
  const :line_2, T.nilable(String)
  prop  :verified, T::Boolean, default: false   # `prop` is mutable, `const` isn't
end

class Direction < T::Enum
  enums do
    Left = new(:left)
    Right = new(:right)
  end
end
```

Rules from `editorder`:

- `T::Struct` for a hash with known keys. **Data only, never behavior.**
- Name it for the thing (`ShippingAddressStruct`), never `Data` or `Value`.
- **Avoid Sorbet shapes** — `T::Hash[Symbol, T.untyped]` standing in for a
  record types nothing and reads worse than the struct.
- A `T::Enum` doesn't compare to a symbol. Cross the boundary explicitly with
  `.serialize` / `.deserialize`.

**Gotcha:** two `T::Struct` instances with identical attributes are **not**
`==`. In a spec that shows up as an `eq` failure that reads like a data bug.
`Data.define` objects *do* compare by value — prefer `Data` when Sorbet isn't
demanding a `T::Struct`. (`sorbet-struct-comparable` exists if you must.)

## Interfaces and abstract classes

```ruby
module Pet
  extend T::Sig
  extend T::Helpers
  interface!                      # every method abstract; include-only

  sig { abstract.params(food: Food).void }
  def feed(food); end
end
```

`interface!` — all methods abstract, module may only be `include`d.
`abstract!` — mix of concrete and abstract, blocks direct instantiation.

This is the seam that makes a collaborator injectable *and* type-checked: the
constructor takes `client: HttpClient` where `HttpClient` is an `interface!`
module, and a test passes a real fake that implements it.

## Tapioca and RBI files

```sh
bin/tapioca gems              # RBIs for every gem → sorbet/rbi/gems/, commit these
bin/tapioca dsl               # RBIs for runtime-generated methods (Rails models) → sorbet/rbi/dsl/
bin/tapioca dsl --verify      # CI gate: fails if committed DSL RBIs are stale, writes nothing
bundle exec srb tc            # the actual type check
```

`editorder` runs `bundle exec srb tc --did-you-mean=false --ignore=vendor/` and
regenerates with `./bin/update_sorbet`. Config lives in `sorbet/config` (one
flag per line) and `sorbet/tapioca/config.yml`.

Run `srb tc` as a **distinct step after the tests go green**, not instead of
them: mocked specs pass happily against a wrong signature. `editorder`'s TDD
loop is red → green → refactor → **type check** → commit.

## RBS — Shopify runs both; you stay on `sig`

Sorbet can parse inline RBS comments (`#: (Integer) -> String`) behind
`--enable-experimental-rbs-signatures` / `--enable-experimental-rbs-assertions`.
Still experimental-flagged as of 2026-09; I could not confirm it has graduated.

Shopify is not choosing between the two — it runs **both, concurrently**:

- `ruby-lsp`'s own source is typed with `rbs_inline` comments (`#: String`,
  `#: (Array[String] deps) -> DetectionResult`), not `sig` blocks.
- `rubocop-shopify` accommodates RBS twice over — `Layout/LeadingCommentSpace:
  AllowRBSInlineAnnotation: true`, plus a Jan-2026 commit disabling
  `Style/RedundantSelf` because it conflicted with `self #: as untyped`.
- And Sorbet tooling stays actively maintained in parallel — `tapioca`, `rbi`,
  `rubocop-sorbet`, `spoom` all saw commits within a week of 2026-09-21, and a
  Nov-2025 commit disabled `Style/BisectedAttrAccessor` for clashing with sigs.
- The one thing Shopify *did* abandon is `rbs_parser`, the RBS→RBI bridge
  (archived 2025-05). A bridging strategy died; RBS-inline itself did not.

Read that as "two notations for two contexts" — `rbs_inline` for lighter
library-adjacent code, Sorbet `sig` where the tooling earns its weight.

**For this house, stay on `sig` blocks.** `editorder` is entirely Sorbet —
1714 files at `true` or `strict` — Tapioca/`srb tc`/editor integration are
mature today, and mixing notations in one codebase buys nothing. Pick RBS only
if the requirement is explicitly "signatures live outside the implementation file."

Historical note worth knowing: `rubocop-shopify` declined to enforce Ruby 3.1
hash shorthand back in 2022 partly because **Sorbet didn't support it yet**
(PR #365). That constraint is long gone — the shorthand is house policy now —
but it's a good reminder to check whether a Sorbet limitation you read about
still exists.
## Ruby 4.0 caveat

Ruby 4.0's leading-logical-operator line continuation broke `srb tc`
([sorbet#10589](https://github.com/sorbet/sorbet/issues/10589), closed
2026-08-26 with no linked commit — fix unconfirmed). Sorbet deliberately does
**not** warn about newer-Ruby syntax; it delegates that to RuboCop. So if you
write a leading-`&&` continuation in a typed file, run `srb tc` before
believing it works.
