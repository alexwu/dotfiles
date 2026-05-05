---
name: writing-nim-code
description: "Writes idiomatic Nim that follows NEP-1 (the official Nim style guide) and community conventions, and formats with nph. Use whenever writing, editing, reviewing, or refactoring Nim — .nim, .nims, or .nimble files — including small one-off scripts. Also triggers on questions about Nim naming, idioms, error handling, memory semantics, imports, project layout, or nph formatting. Prefer this skill over guessing: Nim's conventions differ meaningfully from Python/Go/Rust in casing, keyword choice, and std-library naming."
---

# Writing Nim Code

Nim is small, expressive, and opinionated about style. Two things make Nim code look "right":

1. **NEP-1** — the official style guide (naming, indentation, spacing).
2. **nph** — the canonical code formatter, analogous to `gofmt` / `black` / `prettier`.

If nph has run and NEP-1's naming rules are followed, 90% of style debate disappears. This skill is a cheat sheet for the remaining 10% — the idioms that make Nim feel like Nim instead of transliterated C++.

---

## The First Two Rules

### 1. Run `nph` before committing

```sh
nph path/to/file.nim            # format in place
nph src/                        # format a directory
nph --check src/                # CI: exit non-zero if unformatted
nph --diff src/                 # preview without writing
echo "echo 1" | nph -           # stdin/stdout
```

Do not hand-align code. Do not argue with nph's output — if it disagrees with you, the formatter wins. If a project pins an nph version, match it.

### 2. NEP-1 is non-negotiable for naming and indentation

- **Indentation:** 2 spaces. **Tabs are rejected by the compiler.**
- **Line length:** aim for 80 characters.
- **Casing:** `camelCase` for everything except types (`PascalCase`) and non-pure enum values (`camelCase` with a shared prefix).

The rest of this document expands on these and everything around them.

---

## Naming Conventions (NEP-1)

| Kind | Case | Example |
|---|---|---|
| Variables, parameters, fields | `camelCase` | `userCount`, `maxRetries` |
| Procs, funcs, methods, iterators, templates, macros | `camelCase` | `parseUrl`, `isValid` |
| Types (object, ref, tuple, enum, distinct) | `PascalCase` | `HttpRequest`, `ParseError` |
| Constants | `PascalCase` *or* `camelCase` (pick one per project) | `MaxBufferSize`, `defaultPort` |
| Modules / files | `lower_snake_case.nim` | `secret_guard.nim` |
| Generic type parameters | single uppercase letter or `PascalCase` | `T`, `K`, `Value` |
| Enum members (non-pure) | `camelCase`, with a shared prefix | `tkInt`, `tkFloat`, `tkString` |
| Enum members (`{.pure.}`) | `PascalCase`, no prefix | `Color.Red`, `Color.Green` |

**Acronyms are treated as regular words.** `parseUrl`, not `parseURL`. `checkHttpHeader`, not `checkHTTPHeader`. This is the single most common place LLMs get Nim naming wrong.

**Exception and error types end in `Error` or `Defect`:**
```nim
type
  ParseError* = object of CatchableError
  OutOfBoundsDefect* = object of Defect
```
Inherit from `CatchableError` (recoverable) or `Defect` (programming bug) — rarely directly from `Exception`.

**Subject-verb order** in procedure names: `fileExists`, not `existsFile`.

**Mutating vs. copy pairs:**
- `sort` / `sorted`, `reverse` / `reversed`, `rotate` / `rotated` — the past participle returns a new value.
- `m`-prefixed iterators yield mutable references: `mitems`, `mpairs`.

**Getters/setters:** a field getter is named after the field (`foo`, not `getFoo`) unless it has side effects or is non-O(1). Setters use the `foo=` syntax.

---

## Standard Library Name Abbreviations

Nim's stdlib uses short names consistently. Match them in your own code so it reads cohesively:

| Full word | Use |  | Full word | Use |
|---|---|---|---|---|
| length | `len` |  | configuration | `cfg` |
| capacity | `cap` |  | message | `msg` |
| compare | `cmp` |  | argument | `arg` |
| initialize (value type) | `initFoo` |  | parameter | `param` |
| new (ref type) | `newFoo` |  | variable | `var` |
| append | `add` (not `append`) |  | value | `val` |
| delete | `del` (fast) / `delete` (order-preserving) |  | string | `str` |
| include / exclude | `incl` / `excl` |  | identifier | `ident` |
| execute | `exec` |  | directory | `dir` |
| environment | `env` |  | extension | `ext` |
| command | `cmd` |  | separator | `sep` |
| application | `app` |  | column | `col` |

Don't invent your own abbreviations — either use the full word or the stdlib convention.

---

## Idioms That Make Code Feel Native

### `let` over `var` over `const`

- `const` — compile-time constant. First choice for fixed values.
- `let` — runtime immutable. Default for locals that don't reassign.
- `var` — mutable. Only when you actually mutate.

```nim
const MaxRetries = 3                       # compile-time
let now = getTime()                        # runtime, immutable
var buffer = newSeq[byte](MaxRetries * 8)  # mutable
```

If a variable is never reassigned after its declaration, it should be `let`. This is a NEP-1 SHOULD, enforced by `nimsuggest` and most community linters.

### `func` over `proc` when pure

A `func` is a `proc` with `{.noSideEffect.}` applied. Use `func` whenever the body doesn't do I/O, mutate globals, or raise. The compiler enforces purity and gives you a free correctness guarantee.

```nim
func square(x: int): int = x * x           # pure
proc logLine(msg: string) = echo msg       # side effect: stdout
```

### Use the implicit `result`

Procs with a return type have an implicit `result` variable initialized to the type's default. Prefer assigning to `result` and falling off the end over explicit `return`.

```nim
# idiomatic
func sumPositive(xs: seq[int]): int =
  for x in xs:
    if x > 0:
      result += x

# avoid
func sumPositive(xs: seq[int]): int =
  var total = 0
  for x in xs:
    if x > 0:
      total += x
  return total
```

Use `return` only when its control-flow property (early exit) is the point.

### Prefer `proc` over macros/templates/iterators/converters

NEP-1 SHOULD: reach for the more powerful facilities only when you actually need them. Macros are for syntax manipulation; templates for AST substitution; iterators for custom `for`-loop protocols; converters for implicit coercion (usually a mistake — avoid). If a `proc` works, use a `proc`.

### `openArray[T]` for array/seq parameters

Accept `openArray[T]` when a proc reads but doesn't store the collection — callers can pass a `seq`, `array`, or slice without conversion.

```nim
func sum(xs: openArray[int]): int =
  for x in xs: result += x

discard sum([1, 2, 3])              # array literal
discard sum(@[1, 2, 3])             # seq
discard sum(mySeq.toOpenArray(0, 4))
```

### Range syntax

Slices and ranges use `..` (inclusive) and `..<` (exclusive) with **no spaces**:

```nim
for i in 0..<len(xs):     # exclusive, preferred for indices
for c in 'a'..'z':        # inclusive
let tail = xs[1..^1]      # second-to-last item
```

Exception: add a space before a unary operator, e.g. `1 .. -3`.

### UFCS (method-call syntax)

`foo(x, y)` and `x.foo(y)` are equivalent. Prefer the method-call form for chains of transformations:

```nim
# idiomatic
let slugs = names.mapIt(it.toLowerAscii).filterIt(it.len > 0)

# less idiomatic
let slugs = filterIt(mapIt(names, it.toLowerAscii), it.len > 0)
```

### Triple-quoted strings start on a new line

```nim
# preferred
let sql = """
  SELECT id, name
  FROM users
  WHERE active = true
"""

# avoid — first line is indented differently from the rest
let sql = """SELECT id, name
FROM users
WHERE active = true"""
```

---

## Imports

### Use the `std/` prefix (Nim 1.4+)

```nim
import std/[json, os, strutils, re]   # multiple modules
import std/strformat                  # single module
```

The bare `import json` still works for now, but `std/` is the documented convention in modern Nim and makes it obvious at a glance which imports are stdlib vs. third-party.

### Selective imports

```nim
import std/strutils except parseInt          # drop one symbol
from std/os import getEnv, putEnv            # bring in only two
import ./internal/parser                     # relative path
```

Don't re-export with `export` unless you're deliberately building a facade module — it makes dependency tracking harder.

### One import group per origin

Organize by:
1. stdlib (`std/…`)
2. third-party (nimble packages)
3. local / relative

Separated by blank lines. `nph` won't enforce this but it keeps diffs clean.

---

## Error Handling

### Raising

```nim
raise newException(ValueError, "port must be 1..65535")
```

Don't construct exceptions manually with `raise ValueError(msg: "...")` — `newException` sets the stack trace and parent pointer correctly.

### Custom exception types

```nim
type ConfigError* = object of CatchableError

proc loadConfig(path: string): Config =
  if not fileExists(path):
    raise newException(ConfigError, "config not found: " & path)
```

### Exception tracking

Add `{.raises: [FooError].}` (or `{.raises: [].}` for "raises nothing") when you want the compiler to enforce which exceptions a proc can propagate. This is the Nim equivalent of Java's checked exceptions, but opt-in.

```nim
func parsePort(s: string): int {.raises: [ValueError].} =
  result = parseInt(s)
  if result notin 1..65535:
    raise newException(ValueError, "out of range")
```

### Optional values vs. exceptions

- **`Option[T]`** (`std/options`) — when absence is expected and the caller routinely handles both cases.
- **Exceptions** — when the error is exceptional and most callers won't want to handle it inline.
- **`Result[T, E]`** — available via the community `results` package; common in the status-im ecosystem (nimbus, nim-chronos). Reach for it when you want forced error handling without exception overhead.

Don't reinvent `Result` with a custom object. Either use exceptions, `std/options`, or add `results` as a dep.

---

## Memory and Performance

Nim 2.0+ defaults to **ORC** (cycle-collecting ARC). You rarely need to think about memory management, but three things help when you do:

### `sink` parameters

Marks a parameter that will be consumed (moved, not copied). Use for "I'm taking ownership":

```nim
proc store(items: var seq[string], s: sink string) =
  items.add(s)                # no copy of s

var names = @["a", "b"]
let userInput = readLine(stdin)
names.store(userInput)        # userInput moves in; don't reuse after
```

### `lent` returns

Returns a borrowed view; avoids a copy for read-only access.

```nim
func firstName(u: User): lent string = u.name
```

### Avoid accidental `seq` copies

Passing a `seq` by value copies the whole thing. Accept `openArray[T]` for read-only, `var seq[T]` for mutation in place, or use `lent`/`sink` for explicit ownership.

### Compile flags worth knowing

- `-d:release` — optimize, strip bounds checks, strip asserts.
- `-d:danger` — release + strip *everything* (no overflow checks). Only once you've measured.
- `--mm:orc` — explicit ORC (default in Nim 2.0+).
- `--mm:arc` — ARC without cycle collector; faster but leaks reference cycles.
- `--threads:on` — enable threading (default on in newer Nim).

---

## Pragmas

Pragmas go after the identifier they annotate, in `{.foo.}` syntax:

```nim
proc fastPath() {.inline.} =
  discard

proc entryPoint() {.exportc.} =
  discard

when isMainModule:
  main()
```

Common pragmas:
- `{.inline.}` — suggest inlining.
- `{.noSideEffect.}` — assert purity (equivalent to using `func`).
- `{.raises: [].}` — exception tracking (see above).
- `{.deprecated: "use newThing instead".}` — deprecation warning.
- `{.discardable.}` — caller may ignore the return value without `discard`.
- `{.pure.}` on enums — no prefix required on members.
- `{.push raises: [].}` / `{.pop.}` — apply a pragma to a whole block.

---

## Testing

### stdlib `unittest`

Perfectly adequate for most projects:

```nim
import std/unittest

suite "parser":
  test "parses empty input":
    check parse("") == @[]
  test "rejects garbage":
    expect ParseError:
      discard parse("\x00\x01")
```

Run with `nim c -r tests/test_foo.nim` or via `nimble test`.

### Community alternatives

- **`balls`** (github.com/disruptek/balls) — nicer runner, parallel tests, less macro noise. Widely used in the wider community.
- **`testament`** — the Nim compiler's own test runner. Only reach for it if you're testing compiler behavior itself.

Unless a project already uses one of the above, default to `unittest`.

---

## Project Layout

A standard `nimble` project looks like:

```
myproject/
├── myproject.nimble         # package manifest
├── src/
│   ├── myproject.nim        # library entry point (matches package name)
│   └── myproject/
│       ├── parser.nim
│       └── runtime.nim
├── tests/
│   ├── config.nims          # sets test-time flags
│   └── test_parser.nim
└── README.md
```

Key conventions:
- **Filenames use `lower_snake_case.nim`** — they must be valid Nim identifiers (hyphens are not allowed in source filenames, even if the binary output name uses them).
- **Binary name can differ from source name** via `-o:` or the `.nimble` file's `bin` field — use this when you want a `my-tool` executable from `my_tool.nim`.
- **`src/<package>.nim`** is the library entry; `src/<package>/` holds submodules.
- **`tests/test_*.nim`** are picked up automatically by `nimble test`.
- **`.nimble` file** uses the NimScript dialect — it *is* Nim, not TOML.

### Executable entry point

For `nim c`-compiled binaries, guard `main` with `isMainModule`:

```nim
proc main() =
  # CLI logic
  discard

when isMainModule:
  main()
```

This lets the same file be imported as a library without running `main`.

### CLI argument parsing

- **`std/parseopt`** — tiny, no deps, awkward API.
- **`cligen`** (github.com/c-blake/cligen) — de-facto community standard. Derives a CLI from a proc signature via a macro:

```nim
import cligen

proc greet(name = "world", shout = false) =
  let s = "hello, " & name
  echo if shout: s.toUpperAscii else: s

when isMainModule:
  dispatch(greet)
```

Use `cligen` unless you have a reason not to.

---

## Documentation Comments

Nim has two comment syntaxes:

- `#` — regular comment, discarded by the parser.
- `##` — doc comment, captured by `nim doc` for generated HTML.

Place doc comments **inside** the thing they document, on the first line of the body:

```nim
proc parsePort(s: string): int =
  ## Parses a TCP port. Raises ValueError on out-of-range.
  result = parseInt(s)
  if result notin 1..65535:
    raise newException(ValueError, "port out of range")
```

For modules, put the doc comment at the top of the file *before any imports*:

```nim
## Parses HTTP headers into a case-insensitive table.
##
## Example:
## ```nim
## let h = parseHeaders("Host: example.com\r\n")
## ```

import std/[strutils, tables]
```

Use RestructuredText (`.. code-block:: nim`) or Markdown fenced code blocks — `nim doc` supports both.

---

## Common Anti-Patterns

| Don't | Do |
|---|---|
| `var x = getValue()` when `x` is never reassigned | `let x = getValue()` |
| `return result` at the end of a proc | fall off the end |
| `proc` for a pure function | `func` |
| `parseURL`, `parseHTTPHeader` | `parseUrl`, `parseHttpHeader` |
| `a .. b` (spaces) | `a..b` |
| `raise ValueError(msg: "bad")` | `raise newException(ValueError, "bad")` |
| `append` / `push` / `enqueue` | `add` |
| `import json, os, strutils` (no prefix) | `import std/[json, os, strutils]` |
| `seq` parameter for read-only collection | `openArray[T]` |
| Hand-formatted alignment | let `nph` decide |
| Filename `my-module.nim` | `my_module.nim` |
| Comments explaining *what* the code does | comments explaining *why* |

---

## Quick Gotchas

- **`std/re` can't compile patterns at `const` time in Nim 2.2+.** Use `let` at module scope for regex literals.
- **`std/regex`** (third-party `nim-regex`) is usually preferable to `std/re` (which wraps PCRE).
- **Integer overflow is a runtime exception** by default. `-d:release` keeps the check; `-d:danger` removes it.
- **`==` on `ref object` compares identity**, not contents. Override `==` yourself if you want structural equality.
- **`echo` converts via `$`**; define `proc \`$\`(x: MyType): string` for custom string conversion.
- **Order of top-level code matters** — Nim compiles top-down. Forward-declare procs with `proc foo(): int` if call order forces it, or reorder.

---

## Workflow Checklist (before shipping a change)

1. `nph <files you touched>` — or `nph src/` for a wider sweep.
2. `nim check <entry>.nim` — fast type-check, no code gen.
3. `nimble test` (or `nim c -r tests/test_whatever.nim`) — run tests.
4. Scan for `TODO`/`FIXME` you introduced.
5. If adding a public API, add a `##` doc comment.
6. If the change is user-facing, update the `.nimble` `version`.

---

## When This Skill Is Not Enough

- **Nim manual:** https://nim-lang.org/docs/manual.html — authoritative on language semantics.
- **NEP-1:** https://nim-lang.org/docs/nep1.html — the full style guide.
- **nph:** https://github.com/arnetheduck/nph — formatter source and docs.
- **Nim by Example:** https://nim-by-example.github.io — short, pragmatic patterns.
- **Nim forum / IRC / Discord** — the community is small and friendly; Araq (Nim's BDFL) often weighs in directly.
