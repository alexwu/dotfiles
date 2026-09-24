# Style — what rubyfmt handles, and what's yours

The Shopify Ruby Style Guide is the baseline. Most of its Layout chapter is
**already implemented by rubyfmt**, so the useful question isn't "what does the
guide say" but "what does the guide say that no tool will do for me."

All rubyfmt behavior below was verified by running rubyfmt 0.14.1, not read
from its docs.

## rubyfmt already does this — don't hand-format it

Verified by feeding it deliberately-wrong input:

| Input | rubyfmt output |
|---|---|
| `'single quotes'` | `"single quotes"` |
| `a = { x: 1, y: 2 }` | `a = {x: 1, y: 2}` — **no inner padding on hash braces** |
| `[1,2].map { \|n\| n + 1 }` | `[1, 2].map { \|n\| n + 1 }` — block braces **do** get padding |
| `result = if c` / hanging-indented branches | branches indented one level, `else`/`end` flush with `result =` |
| `x = { a: 1,` / `      b: 2 }` | exploded, one pair per line, `}` on its own line |
| `User.pluck(:name)` / `    .sort(...)` | receiver alone on line 1, each `.call` indented one level |
| `def foo` / ` return 1` | re-indented to 2 spaces |

So: 2-space indent, quote style, brace spacing, chain layout, conditional
assignment shape, heredoc indentation — **run the formatter, don't argue.**

## rubyfmt contradicts the guide in three places

The formatter wins. Don't hand-fix these back toward the guide:

1. **Trailing commas.** The guide mandates a trailing comma in multi-line
   collection literals. rubyfmt **strips** them — fed `from: "b",` it returns
   `from: "b"`. `rubocop-shopify` also disables all three `TrailingComma` cops,
   so nothing enforces the guide's rule. **Don't write trailing commas.**
2. **Lambda spacing.** The guide says `->(x, y)` and explicitly calls
   `-> (x, y)` bad. rubyfmt *adds* the space, producing `-> (x, y) { x + y }`.
3. **End-of-line comments — it relocates them.** rubyfmt only emits comments on
   their own line, so it *moves* a trailing comment up one line. Verified:
   ```ruby
   foo = bar(1, 2) # rubocop:disable Some/Lint   # in
   # rubocop:disable Some/Lint                   # out — and no matching enable,
   foo = bar(1, 2)                               # so it now applies to EOF
   ```
   A scoped disable silently becomes a file-wide one. Use the wrapping
   `# rubocop:disable` / `# rubocop:enable` pair. `rubocop-rubyfmt` ships
   `Rubyfmt/NoEndOfLineRubocopDisables` with an autocorrect to catch it.

## rubyfmt will NOT do this — it's on you

- **Line breaking.** rubyfmt has no width flag and does not wrap. A 115-char
  line passes through untouched. You choose the breaks; `Layout/LineLength:
  Max: 100` catches what you got wrong afterwards.
- **A blank line after a visibility modifier.** rubyfmt adds the blank line
  *above* `private` but not below it. The guide wants both.
- Anything semantic: `%w[]` vs a literal array, `fetch` vs `[]`,
  `class << self` vs `def self.`. Those are RuboCop's or yours.

## Syntax rules worth internalizing

Ordered by how often an agent gets them wrong.

- **Guard clauses over nesting.** Bail at the top; three levels of block
  nesting is the ceiling.
  ```ruby
  def compute(thing)
    return unless thing[:foo]
    return re_compute(thing) unless thing[:foo][:bar]
    partial_compute(thing)
  end
  ```
- **Keyword arguments over an options hash.** Always.
- **Omit `return` and `self` where possible**; `self.` only where an attribute
  writer needs it (`self.name = x`).
- Parentheses on method definitions and calls **with** arguments; omit them
  with none, for class-macro calls with an implicit receiver (`has_many :posts`,
  `include Bar`), and for `require`, `require_relative`, `require_dependency`,
  `yield`, `raise`, `puts`.
- `&&`/`||`, never `and`/`or`. `!`, never `not`.
- `unless` for a negative condition — but **never `unless/else`**; flip it.
- Ternary for a one-expression branch; never nested, never multi-line.
- `{...}` for single-line blocks, `do...end` for multi-line.
- `names.map(&:upcase)` when the block is a single method call.
- `->(x) { ... }` over `lambda`; `proc` over `Proc.new`.
- Wrap an assignment used as a condition: `if (value = /foo/.match(string))`.
- `||=` to initialize — but **never for booleans**. `@enabled ||= true` sets
  `true` even when it was deliberately `false`. Use
  `@enabled = true if @enabled.nil?`.
- `public_send` over `send` — `send` bypasses `private`, which is usually an
  accident.
- Avoid `for`, avoid `then`, avoid `;`, avoid block comments (`=begin`).

## Naming

- `snake_case` for methods, variables, symbols, files, directories.
- `CamelCase` for classes and modules, acronyms stay upper (`HTTPClient`,
  `XMLParser`).
- `SCREAMING_SNAKE_CASE` for other constants.
- Predicates end in `?` **and return a boolean**. No `is_` prefix (`empty?`,
  not `is_empty?`), no `get_` prefix.
- A `!` suffix only where a non-bang sibling exists — bang means "more
  dangerous than the other one," not "does something."
- Binary operator parameters are named `other` (except `<<` and `[]`).
- `|hash, e|` for `inject` — name by what's being injected.
- No magic numbers; name the constant.
- Nothing with discriminatory origins.

## Classes and modules

- **`class << self`, grouped in one block** — not scattered `def self.foo`.
  The reason is concrete: `private` does **not** apply to a `def self.` below
  it, so the scattered form ships public methods you thought were private.
  ```ruby
  class SomeClass
    class << self
      def build; end

      private

      def helper; end       # actually private
    end

    def instance_method; end
  end
  ```
- `extend self` over `module_function` for a namespace of functions.
- Prefer a module to a class that only has class methods.
- `attr_reader`/`attr_accessor` for trivial accessors, blank line above and
  below. Never `attr`. Never `@@class` variables.
- One class or module per file; the filename is its `snake_case`.
- **Don't write `class A::B`** — constant lookup won't search `A`, so a
  constant defined in `A` raises `NameError` inside `B`. Nest the modules.
- `alias_method` over `alias`.
- Visibility modifiers indented to the same level as the methods they govern.

## Exceptions

- `raise SomeError, "message"` — two args. The instance form
  (`raise SomeError.new("msg")`) can't take a backtrace as a third argument.
- `raise "message"` is already a `RuntimeError`; don't name it.
- Implicit `begin`: put `rescue` directly in the method body, not nested.
- **Never `rescue Exception`** — that catches `SystemExit` and signals. A bare
  `rescue` is `StandardError`, which is what you want.
- **No empty `rescue`, no `rescue nil` modifier.** `do_something rescue nil`
  swallows `NoMethodError` and typos too.
- **Never `return` from `ensure`** — it discards the in-flight exception.
- Same trap in memoized assignment — this is `Lint/NoReturnInMemoization`, one
  of only two custom cops `rubocop-shopify` ships, which tells you how often it
  bites:
  ```ruby
  # bad — the return skips the assignment
  def foo
    @foo ||= begin
      return 1 if flag?
      2
    end
  end
  ```
- Name it `error`, not `e`. **Delete an unused rescue variable** rather than
  writing `=> _e` (`editorder`'s rule — `Lint/UselessAssignment`).
- Prefer stdlib exception classes to a new hierarchy.

## Collections

- Literal `[]` / `{}` over `Array.new` / `Hash.new`.
- **`Hash#fetch` when the key must exist** — `[]` returns `nil` on a typo and
  you find out three frames later. `fetch(key, default)` for defaults, because
  `hash[key] || default` is wrong when the value is legitimately `false`.
- `first`/`last` over `[0]`/`[-1]`. `key?`/`value?` over `has_key?`/`has_value?`.
  `map`/`find`/`select`/`size` over `collect`/`detect`/`find_all`/`length`.
- Symbol-key shorthand `{a: 1}`; hash rockets only when **not all** keys are
  symbols (`{:a => 1, "b" => 2}`).
- The guide prefers literal arrays over `%w`/`%i` — note `Style/WordArray` and
  `Style/SymbolArray` are **disabled** in `rubocop-shopify`, so this is
  advisory, and rubyfmt leaves `%w[a b c]` alone.
- Never a mutable object as a hash key.

## Strings and regexps

- Double quotes. Interpolation over concatenation. `"#{result}"`, not
  `"#{result.to_s}"`. `{}` around interpolated ivars: `"#{@first_name}"`.
- No padding inside interpolation: `"#{user.name}"`, not `"#{ user.name }"`.
- `sub`/`tr`/`delete` over `gsub` when the narrower method works.
- Squiggly heredocs `<<~SQL`, contents and terminator indented to the opening.
- **`\A` and `\z`, not `^` and `$`**, when anchoring a whole string — `^`/`$`
  match line boundaries, which is a real injection vector.
- Non-capturing `(?:...)` when the capture is unused; named groups over
  numbered; `Regexp#match` over `$1`.
- `%r` only for patterns containing a literal `/`.
- Avoid `?x` character literals and `%q` unless the string has both quote kinds.

## General

- Single Level of Abstraction: every line of a method operates at the same
  altitude.
- Code functionally; avoid mutation and avoid mutating arguments.
- Avoid defensive programming, needless metaprogramming, monkeypatching, long
  methods, long parameter lists.
- Comments explain **why**, not what. Keep them in sync or delete them.
- `ruby -w`-safe code. UTF-8, Unix line endings, newline at EOF, no trailing
  whitespace.
