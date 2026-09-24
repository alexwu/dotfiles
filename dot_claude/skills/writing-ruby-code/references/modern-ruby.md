# Modern Ruby (3.0 → 4.0)

Every entry carries its floor. Check the repo's Ruby first (`SKILL.md` Step 0)
— on this machine the dev box is 4.0.6 and the main work repo is 3.2.2, so
"works in my scratch buffer" proves nothing.

Current stable: **4.0.7** (2026-09-15). Ruby never shipped a 3.5 — 3.4.x went
straight to 4.0.0 on 2025-12-25. 4.0 is a 30th-anniversary version number, not
a breaking rewrite.

## Pattern matching — 3.0

Reach for it when you would otherwise write a chain of `dig`/`fetch`/`is_a?`
against a nested payload. It destructures and type-checks in one shape.

```ruby
case response
in {status: 200, body:}
  handle(body)
in {status: Integer => code} if code >= 500
  retry_later(code)
in {status: 404}
  nil
end
```

Make your own objects matchable with `deconstruct_keys` (array patterns use
`deconstruct`). `Data.define` generates both for free:

```ruby
Measure = Data.define(:amount, :unit)

case Measure[10, "km"]
in Measure(amount:, unit: "km") then "#{amount} kilometers"
end
```

**Find pattern** — matches a run anywhere in an array. Still flagged
experimental through 4.0.7, so don't put it on a hot path you can't revisit:

```ruby
case ["a", "b", "c", "d"]
in [*, "c", *post] then post   # => ["d"]
end
```

**Rightward assignment** `=>` destructures or raises; `in` returns a boolean:

```ruby
config => {host:, port:}   # raises NoMatchingPatternError if it doesn't fit
value in Integer           # => true/false, no raise
```

Note `case/in` is **exhaustive** — a value matching no branch raises
`NoMatchingPatternError`. That is usually what you want (it is the closest Ruby
gets to a compiler telling you a case is unhandled), but add `else` when a
miss is legitimate.

## Endless methods — 3.0 (settle on 3.1 syntax)

```ruby
def square(x) = x * x
def full_name = "#{first_name} #{last_name}"
def admin? = role == "admin"
```

Single expression, no side effects. **Never** `def initialize`, never a
multi-line body crammed onto one line, never something that writes state.
`Style/EndlessMethod` is enabled in `rubocop-shopify` at its default
`allow_single_line`, which encodes exactly this.

## Hash shorthand & kwarg punning — 3.1

```ruby
name = "Luna"
role = "assistant"

{name:, role:}          # => {name: "Luna", role: "assistant"}
create_user(name:, role:)
```

Use it whenever the key matches the local name. It is **valid Ruby** and has
been mis-flagged as a syntax error by agents working in `editorder` — that is
the reason the repo has a rule about it. rubyfmt formats it as `{name:, role:}`
with no inner padding.

## Data.define — 3.2

```ruby
Money = Data.define(:cents, :currency) do
  def to_s = format("%.2f %s", cents / 100.0, currency)
end

m = Money.new(cents: 1050, currency: "USD")   # or Money[1050, "USD"]
m.with(cents: 2000)                            # non-destructive copy
m == Money[1050, "USD"]                        # => true, value equality
```

Free: `==` by value, `to_h`, `deconstruct`, `deconstruct_keys`, frozen
instances, keyword **and** positional constructors.

| Want | Use |
|---|---|
| Immutable value object | `Data.define` |
| Same, but Sorbet must type the fields | `T::Struct` |
| Mutation or `obj[0]` positional access | `Struct` |
| Ordering | mix in `Comparable` + `<=>` (orthogonal to the above) |

`Struct.new(keyword_init: true)` is redundant from 3.2 — plain `Struct.new`
accepts either form. Drop the ceremony in new code.

## Anonymous forwarding — 3.0 / 3.1 / 3.2

Naming a parameter only to re-pass it unchanged is noise in a wrapper.

```ruby
def instrument(...)  = target(...)   # 3.0: everything
def logged(&)        = with_log(&)   # 3.1: block only
def wrap(*, **)      = inner(*, **)  # 3.2: positional + kwargs
```

`editorder` sets `Naming/BlockForwarding: explicit` (it wants `&block`), so
follow the repo there rather than this default.

## `it` — 3.4

```ruby
[1, 2, 3].map { it * 2 }
```

Only for a trivial single-argument block on 3.4+. `_1` is the fallback below
3.4 and the only option for multi-argument blocks. Anything past one short
clause gets a named parameter — `{ |user| ... }` beats both.

## Collection & object methods worth defaulting to

```ruby
{a: 1, b: 2}.except(:b)                  # 3.0
%w[a b a].tally                          # => {"a" => 2, "b" => 1}
(1..6).filter_map { it * 2 if it.even? } # map + compact in one pass
5.clamp(1, 3)
value.then { normalize(it) }.then { persist(it) }   # pipeline without a temp
```

`each_cons`/`each_slice` return lazy enumerators without a block — stop
building intermediate arrays by hand.

## Frozen string literals — still not the default, even in 4.0

Verified on 4.0.6 rather than assumed:

```
$ ruby -e 's = "abc"; s << "d"; puts s'        # => abcd   (no error, no warning)
$ ruby -W:deprecated -e 's = "abc"; s << "d"'  # warning: literal string will be frozen in the future
$ ruby --enable=frozen-string-literal -e 's = "abc"; s << "d"'   # FrozenError
```

Literals are **chilled**: `frozen?` is `false`, mutation succeeds, and the
warning only appears under `-W:deprecated`. So:

```ruby
# frozen_string_literal: true

# ... blank line between the magic comment and the code, per the style guide.
```

on every file, every time. There is still no default-frozen Ruby version, and
nothing in 4.0 moved this forward.

## Concurrency, in one line each

- **Ractor** — experimental since 3.0 and *still* experimental in 4.0.7; core
  hopes to drop the tag around 4.1. Most gems aren't Ractor-safe. Don't
  recommend it. (4.0 also **removed** `Ractor#take`/`#yield` in favour of
  `#join`/`#value` and `Ractor::Port`, so old Ractor code breaks outright.)
- **Fiber Scheduler** — this is the one that works. `async`, Falcon, and
  Faraday's net-http adapter build real non-blocking I/O on it today. Reach
  here for I/O-bound concurrency.

## What 4.0 actually changed

Additive and mostly invisible to application code:

- Logical operators (`&&`, `||`, `and`, `or`) may now **start** a continuation
  line, the way a leading `.` has since 1.9. See the Sorbet caveat in
  `SKILL.md` Gotchas before using this in a typed file.
- `*nil` no longer calls `nil.to_a` — it is just "no arguments" now. A real
  semantic change if anything overrode `NilClass#to_a`.
- `Set` reimplemented in C (it has been autoload-available since **3.2**).
- `Pathname` available without `require`.
- `Ruby::Box` namespaces — experimental, `RUBY_BOX=1`.
- `ZJIT` — experimental, explicitly **not yet as fast as YJIT**. Keep `--yjit`
  for anything performance-sensitive.

Breaking, but narrow: `SortedSet` removed from stdlib; `cgi` gutted to
`cgi/escape`; `Process::Status#&`/`#>>` removed; `Ractor#take`/`#yield`
removed. None of these touch mainstream app code.

## Deprecated — don't write these

| Don't | Since | Instead |
|---|---|---|
| Rely on a trailing hash becoming kwargs | removed 3.0 | splat explicitly: `foo(1, **opts)` |
| `Object#=~` on non-String/Regexp | raises 3.2 | `match?` / explicit comparison |
| `taint`/`untaint`/`$SAFE` | gone 3.0–3.2 | nothing; the model is dead |
| `Struct.new(keyword_init: true)` | redundant 3.2 | plain `Struct.new` |
| `Fixnum`/`Bignum`/`Random::DEFAULT` | removed 3.2 | `Integer`, `Random.new` |
| `Dir.exists?` | removed 3.2 | `Dir.exist?` |
| `require "readline"` | retired 3.3 | `reline` |

The positional-hash → kwargs separation is the single biggest porting hazard in
Ruby's recent history. If you are reading pre-3.0 code, assume every trailing
hash at a call site is suspect.
