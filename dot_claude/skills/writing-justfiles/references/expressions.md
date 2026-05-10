# Justfile Expressions — Reference

Everything that lives inside `:=` assignments and `{{…}}` substitutions: variables, strings, interpolation, conditionals, command evaluation. Plus argument-splitting / positional-arguments mode — the principal way to dodge the quoting hazards that this file's interpolation rules create.

For attribute syntax (`[positional-arguments]`, `[env-var]`, etc.), see [`attributes.md`](attributes.md). For built-in function signatures (`env()`, `shell()`, `quote()`, `replace()`, `replace_regex()`, `error()`), see [`built-in-functions.md`](built-in-functions.md). For the full settings table, see [`settings.md`](settings.md). This file describes the expression *language* and links out for the surrounding machinery.

## Table of Contents

1. [Variables and assignments](#1-variables-and-assignments)
2. [Strings](#2-strings)
3. [String interpolation and brace escaping](#3-string-interpolation-and-brace-escaping)
4. [Conditional expressions](#4-conditional-expressions)
5. [Command evaluation — backticks and `shell()`](#5-command-evaluation--backticks-and-shell)
6. [Positional arguments mode and avoiding argument splitting](#6-positional-arguments-mode-and-avoiding-argument-splitting)
7. [User-defined functions (unstable)](#7-user-defined-functions-unstable)

---

## 1. Variables and assignments

Source: <https://just.systems/man/en/variables-and-assignments.html>, <https://just.systems/man/en/getting-and-setting-environment-variables.html>

```just
foo := "hello"
bar := "world"

baz:
    echo {{ foo + " " + bar }}
```

`just --evaluate` prints all module variables; `just --evaluate VAR` prints one.

### `--evaluate-format` (1.49.0+)

```console
$ just --evaluate --evaluate-format shell
bar="world"
foo="hello"
$ just --evaluate --evaluate-format just
bar := "world"
foo := "hello"
```

Useful for sourcing into a shell script.

### Computed via backticks

```just
tmpdir  := `mktemp -d`
git_sha := `git rev-parse --short HEAD`
```

Backticks run at justfile-load time, *not* recipe-time. Don't put expensive computations in unconditional `:=` assignments unless `set lazy` is on (see [`settings.md#set-lazy-1470`](settings.md#set-lazy-1470)).

### `export`

```just
export RUST_BACKTRACE := "1"

test:
    cargo test
```

Variables declared with `export` are exported as env vars to recipe shells. `set export` exports *all* `:=` assignments — see [`settings.md#set-export`](settings.md#set-export). For per-recipe one-shot env without exporting at module scope, see the `[env-var: VALUE]` attribute in [`attributes.md#envvar-value`](attributes.md#envvar-value).

`unexport NAME` (1.29.0+) removes a variable from a recipe's environment:

```just
unexport FOO

@foo:
    echo $FOO
```

```console
$ export FOO=bar
$ just foo
sh: FOO: unbound variable
```

### Backticks don't see exports

Exported variables and parameters are *not* available to backticks in the same scope:

```just
export WORLD := "world"
# This backtick will fail with "WORLD: unbound variable":
BAR := `echo hello $WORLD`
```

Use `shell('echo hello $1', WORLD)` instead — `shell()` accepts arguments explicitly. See [`built-in-functions.md`](built-in-functions.md) for the full signature.

---

## 2. Strings

Source: <https://just.systems/man/en/strings.html>

`'single'`, `"double"`, and `'''triple'''` quoted literals. Inside string literals, `{{…}}` is *not* interpreted as interpolation — that's recipe-body and format-string syntax only.

### Double-quoted (escapes)

```just
carriage-return   := "\r"
double-quote      := "\""
newline           := "\n"
no-newline        := "\
"
slash             := "\\"
tab               := "\t"
unicode-codepoint := "\u{1F916}"
```

`\u{…}` (1.36.0+) accepts up to six hex digits.

### Single-quoted (no escapes)

```just
escapes := '\t\n\r\"\\'
```

```console
$ just --evaluate
escapes := "\t\n\r\"\\"
```

### Multi-line literal strings

```just
single := '
hello
'

double := "
goodbye
"
```

### Indented (triple-quoted) strings

```just
# evaluates to `foo\nbar\n`
x := '''
    foo
    bar
'''

# evaluates to `abc\n  wuv\nxyz\n`
y := """
    abc
        wuv
    xyz
"""
```

Indented strings strip the leading line break and the leading whitespace common to all non-blank lines. Triple-double-quoted forms process escapes after unindenting; triple-single-quoted don't.

### Shell-expanded strings — `x'…'` (1.27.0+)

```just
foobar := x'~/$FOO/${BAR}'
```

| Pattern | Replaced with |
|---------|---------------|
| `$VAR` | env var `VAR` |
| `${VAR}` | env var `VAR` |
| `${VAR:-DEFAULT}` | env var `VAR`, or `DEFAULT` if unset |
| Leading `~` | current user's home directory |
| Leading `~USER` | `USER`'s home directory |

Expansion happens at *compile* time, so `.env`-loaded vars and exported just vars don't apply. But this means `x'…'` works in settings and import paths.

### Format strings — `f'…'` (1.44.0+)

```just
name := "world"
message := f'Hello, {{name}}!'
```

Unlike normal string literals, format strings *do* interpolate `{{…}}`. To embed a literal `{{`, use `{{{{`:

```just
foo := f'I {{{{LOVE} curly braces!'
```

### Backslash line continuation (1.15.0+)

Source: <https://just.systems/man/en/multi-line-constructs.html>

```just
a := 'foo' + \
     'bar'

foo param1 \
    param2='foo' \
    *varparam='': dep1 \
                  (dep2 'foo')
    echo {{param1}} {{param2}} {{varparam}}
```

---

## 3. String interpolation and brace escaping

Source: <https://just.systems/man/en/expressions-and-substitutions.html>

`{{ expr }}` works in:
- Recipe bodies
- Default parameter values (see [`recipes.md`](recipes.md) for how parameters wire into recipe heads)
- Format strings (`f'…'`)

### Operators

| Operator | Behavior |
|---|---|
| `+` | String concatenation: `'foo' + 'bar'` → `'foobar'` |
| `/` | Path-join, always uses `/` (even on Windows). `"a" / "b"` → `"a/b"`. Always inserts `/`, even when one is present (`"a/" / "b"` → `"a//b"`). Prefix `/` for absolute paths (1.5.0+): `/ "b"` → `"/b"` |
| `&&` (1.37.0+, unstable) | `'' && X` → `''`; `'hello' && X` → `X`. Requires `set unstable` — see [`settings.md#set-unstable-1310`](settings.md#set-unstable-1310) |
| `\|\|` (1.37.0+, unstable) | `'' \|\| X` → `X`; `'hello' \|\| X` → `'hello'`. Requires `set unstable` — see [`settings.md#set-unstable-1310`](settings.md#set-unstable-1310) |
| `==` / `!=` | Equality / inequality (used in `if`) |
| `=~` | Regex match (used in `if`) |

### Brace escaping `{{{{`

To emit a literal `{{` in a recipe body, write `{{{{`. The matched `}}}}` becomes `}}` (an unmatched `}}` is ignored, so `}}}}` isn't strictly required, but it reads more clearly).

```just
braces:
    echo 'I {{{{LOVE}} curly braces!'
```

Alternative forms:

```just
braces:
    echo '{{'I {{LOVE}} curly braces!'}}'

braces:
    echo 'I {{ "{{" }}LOVE}} curly braces!'
```

---

## 4. Conditional expressions

Source: <https://just.systems/man/en/conditional-expressions.html>

```just
foo := if "2" == "2" { "Good!" } else { "1984" }

bar:
    @echo "{{foo}}"
```

```just
# Inequality
foo := if "hello" != "goodbye" { "xyz" } else { "abc" }
```

```just
# Regex match — prefer single-quoted strings (no escape interpretation)
foo := if "hello" =~ 'hel+o' { "match" } else { "mismatch" }
```

Regex syntax is the [Rust `regex` crate](https://docs.rs/regex/latest/regex/#syntax).

### Chained — `else if`

```just
foo := if "hello" == "goodbye" {
    "xyz"
} else if "a" == "a" {
    "abc"
} else {
    "123"
}

bar:
    @echo {{foo}}
```

```console
$ just bar
abc
```

### Conditional inside a recipe body

```just
bar foo:
    echo {{ if foo == "bar" { "hello" } else { "goodbye" } }}
```

### Short-circuit evaluation

```just
foo := if env_var("RELEASE") == "true" { `get-something-from-release-database` } else { "dummy-value" }
```

The backtick is only evaluated when the condition is true. The same applies to `error(…)` calls in the unchosen branch — useful for asserting required variables. See [`errors.md`](errors.md) for the full `error()` / `assert()` story; see [`built-in-functions.md`](built-in-functions.md) for `env_var()` and friends.

---

## 5. Command evaluation — backticks and `shell()`

Source: <https://just.systems/man/en/command-evaluation-using-backticks.html>

### Backticks

Run at justfile-load time. Output (stripped of trailing newlines) becomes the variable's value:

```just
localhost := `dumpinterfaces | cut -d: -f2 | sed 's/\/.*//' | sed 's/ //g'`

serve:
    ./serve {{localhost}} 8080
```

### Indented (triple-) backticks

````just
# This evaluates the command `echo foo\necho bar\n`,
# producing the value `foo\nbar\n`.
stuff := ```
    echo foo
    echo bar
  ```
````

De-indented like indented strings.

Backticks may not start with `#!` — that syntax is reserved.

### `shell()` function vs backticks

`shell()` (1.27.0+) is a more general mechanism — it lets you store the command in a variable and pass arguments explicitly (which is the workaround for the "backticks don't see exports" gotcha in §1). See [`built-in-functions.md`](built-in-functions.md) for the full signature.

---

## 6. Positional arguments mode and avoiding argument splitting

Source: <https://just.systems/man/en/settings.html>, <https://just.systems/man/en/avoiding-argument-splitting.html>

The default substitution model — `{{argument}}` pasted into a recipe line — is whitespace-naïve. If `argument` contains spaces, the shell sees them as separators. Positional-arguments mode swaps the substitution model for shell positionals (`$1`, `$2`, …), which preserve quoting. See [`recipes.md`](recipes.md) for how recipe parameters bind in the first place — this section covers what happens when those parameters are interpolated into commands.

`set positional-arguments` (module-wide — see [`settings.md#set-positional-arguments`](settings.md#set-positional-arguments)) or `[positional-arguments]` (per-recipe — see [`attributes.md#positional-arguments`](attributes.md#positional-arguments)). Inside such a recipe:

- `$0` is the recipe name (linewise recipes only)
- `$1`, `$2`, … are the recipe args
- `$@` (sh-compatible shells) expands to all args from `$1`. `"$@"` preserves quoting around whitespace-bearing args.

```just
set positional-arguments

foo argument:
    touch "$1"
```

The trade-off: `just` can't catch typos in `{{argument}}` references because the recipe body is opaque shell. The win: arguments containing spaces or quotes don't break.

### Avoiding argument splitting — three strategies

Source: <https://just.systems/man/en/avoiding-argument-splitting.html>

```just
# 1. Quote the interpolation
foo argument:
    touch '{{argument}}'

# 2. Positional arguments + "$1"
set positional-arguments
foo argument:
    touch "$1"

# 3. Export the parameter — use shell var
foo $argument:
    touch "$argument"
```

Strategy 3 (`$argument`) exports the parameter as an env var for that recipe's shell, so it's referenced via `$argument` (shell var) rather than `{{argument}}` (just interpolation). Combine with `set export` ([`settings.md#set-export`](settings.md#set-export)) to make this the default for all parameters.

### `set positional-arguments` example

```just
set positional-arguments

@foo bar:
    echo $0
    echo $1
```

```console
$ just foo hello
foo
hello
```

`"$@"` expands to all args from `$1` (sh-compatible). PowerShell handles positional args differently — see [`settings.md#set-positional-arguments`](settings.md#set-positional-arguments) for the `pwsh.exe -CommandWithArgs` workaround (PS 7.4+).

---

## 7. User-defined functions (unstable)

Source: <https://just.systems/man/en/user-defined-functions.html>

```just
set unstable

hello(name) := f"Hello, {{ name }}!"

foo:
    echo '{{ hello("World") }}'
```

User-defined functions can reference module-level assignments:

```just
set unstable

base := "foo"

join(extension) := base + "." + extension

create:
    touch {{ join("c") }}
    touch {{ join("html") }}
    touch {{ join("txt") }}
```

Currently unstable — gated behind `set unstable` (see [`settings.md#set-unstable-1310`](settings.md#set-unstable-1310)). Don't rely on this in stable tooling without a fallback. For the built-in equivalents (`replace()`, `replace_regex()`, `quote()`, etc.) that are stable today, see [`built-in-functions.md`](built-in-functions.md).
