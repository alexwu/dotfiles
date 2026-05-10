# Justfile Attributes — Full Reference

Recipes, `mod` statements, and aliases may be annotated with attributes that change behavior. Multiple attributes can stack on separate lines, be comma-separated `[a, b]`, or use colon syntax for single-arg forms `[group: 'name']`. Source: <https://just.systems/man/en/attributes.html>.

## Table of Contents

- [The full table](#the-full-table)
- [Argument attributes — `[arg(...)]`](#arg--argument-constraints--flagify-parameters)
- [`[confirm]` / `[confirm(PROMPT)]`](#confirm--confirmprompt)
- [`[default]`](#default)
- [`[doc]` / `[doc(DOC)]`](#doc--docdoc)
- [`[env(VAR, VALUE)]`](#envvar-value)
- [`[extension(EXT)]`](#extensionext)
- [`[exit-message]`](#exit-message)
- [`[group(NAME)]`](#groupname)
- [`[metadata(...)]`](#metadata)
- [`[no-cd]`](#no-cd)
- [`[no-exit-message]`](#no-exit-message)
- [`[no-quiet]`](#no-quiet)
- [`[parallel]`](#parallel)
- [`[positional-arguments]`](#positional-arguments)
- [`[private]`](#private)
- [`[script]` / `[script(COMMAND)]`](#script--scriptcommand)
- [`[working-directory(PATH)]`](#working-directorypath)
- [OS configuration gates](#os-configuration-gates)

## The full table

| Attribute | Since | Applies to | Description |
|-----------|------:|------------|-------------|
| `[arg(ARG, help="HELP")]` | 1.46.0 | recipe | Print help string `HELP` for `ARG` in usage messages |
| `[arg(ARG, long="LONG")]` | 1.46.0 | recipe | Require `ARG` to be passed as `--LONG` option |
| `[arg(ARG, pattern="PATTERN")]` | 1.45.0 | recipe | Require `ARG` to match regex `PATTERN` (anchored `^…$`) |
| `[arg(ARG, short="S")]` | 1.46.0 | recipe | Require `ARG` to be passed as short `-S` option |
| `[arg(ARG, value="VALUE")]` | 1.46.0 | recipe | Make option `ARG` a flag that injects `VALUE` when present |
| `[confirm]` | 1.17.0 | recipe | Require y/n confirmation before running |
| `[confirm(PROMPT)]` | 1.23.0 | recipe | Same with custom prompt; `PROMPT` may be an expression (1.49.0+) |
| `[default]` | 1.43.0 | recipe | Use as module's default recipe (instead of first-declared) |
| `[doc(DOC)]` | 1.27.0 | module, recipe | Set documentation comment shown in `--list` |
| `[doc]` | 1.27.0 | module, recipe | Suppress the auto-derived doc comment |
| `[env(VAR, VALUE)]` | 1.47.0 | recipe | Set env var for this recipe |
| `[extension(EXT)]` | 1.32.0 | recipe | Set the file extension `just` writes the shebang/script body to |
| `[exit-message]` | 1.39.0 | recipe | Print error message on failure even when `set no-exit-message` is on |
| `[group(NAME)]` | 1.27.0 | module, recipe | Place under group `NAME` in `--list` |
| `[metadata(STRINGS…)]` | 1.42.0 | recipe | Attach metadata strings, surfaced via `just --dump --dump-format json` |
| `[no-cd]` | 1.9.0 | recipe | Don't `cd` into justfile's directory before running |
| `[no-exit-message]` | 1.7.0 | recipe | Suppress `error: Recipe X failed…` on failure |
| `[no-quiet]` | 1.23.0 | recipe | Override `set quiet` and echo the recipe |
| `[parallel]` | 1.42.0 | recipe | Run dependencies concurrently |
| `[positional-arguments]` | 1.29.0 | recipe | Per-recipe `set positional-arguments` |
| `[private]` | 1.10.0 | alias, recipe | Hide from `--list`/`--summary` |
| `[script]` | 1.33.0 | recipe | Execute body via `set script-interpreter` (default `sh -eu`) |
| `[script(COMMAND)]` | 1.32.0 | recipe | Execute body as a script via `COMMAND` |
| `[working-directory(PATH)]` | 1.38.0 | recipe | Set recipe's cwd; `PATH` may be relative or absolute |
| `[android]` | 1.50.0 | recipe | Enable on Android |
| `[dragonfly]` | 1.47.0 | recipe | Enable on DragonFly BSD |
| `[freebsd]` | 1.47.0 | recipe | Enable on FreeBSD |
| `[linux]` | 1.8.0 | recipe | Enable on Linux |
| `[macos]` | 1.8.0 | recipe | Enable on macOS |
| `[netbsd]` | 1.47.0 | recipe | Enable on NetBSD |
| `[openbsd]` | 1.38.0 | recipe | Enable on OpenBSD |
| `[unix]` | 1.8.0 | recipe | Enable on any unix (includes macOS) |
| `[windows]` | 1.8.0 | recipe | Enable on Windows |

## Stacking syntax

Three equivalent ways to apply multiple attributes:

```just
# Multi-line
[no-cd]
[private]
foo:
    echo "foo"

# Single line, comma-separated (1.14.0+)
[no-cd, private]
foo:
    echo "foo"

# Single-arg attributes can use colon syntax
[group: 'bar']
foo:
```

## `[arg]` — Argument Constraints / Flagify Parameters

The `[arg(ARG, …)]` family configures how a recipe's parameter is collected and validated. Available keys: `help`, `long`, `pattern`, `short`, `value`.

### `[arg(ARG, pattern="PATTERN")]` (1.45.0)

Require values of `ARG` to match a regex. A leading `^` and trailing `$` are added implicitly, so the pattern must match the *entire* argument value.

```just
[arg('n', pattern='\d+')]
double n:
    echo $(({{n}} * 2))

[arg('flag', pattern='--help|--version')]
info flag:
    just {{flag}}
```

### `[arg(ARG, long[="LONG"])]` (1.46.0)

Force the parameter to be passed via a long option. Without an explicit name, the long option defaults to the parameter name.

```just
[arg("bar", long="bar")]
foo bar:
```

```console
$ just foo --bar hello
bar=hello
$ just foo --bar=hello
bar=hello
```

```just
# Equivalent — `long` without a value uses the param name.
[arg("bar", long)]
foo bar:
```

### `[arg(ARG, short="S")]` (1.46.0)

Force the parameter to be passed via a short option `-S`. Variadic (`+`/`*`) parameters cannot be options.

```just
[arg("bar", short="b")]
foo bar:
```

```console
$ just foo -b hello
bar=hello
```

### `[arg(ARG, value="VALUE")]` (1.46.0)

Combined with `long` or `short`, makes the parameter a *flag* — it takes no value on the command line, but injects `VALUE` when present.

```just
[arg("bar", long="bar", value="hello")]
foo bar:
```

```console
$ just foo --bar
bar=hello
```

The flag is optional if its parameter has a default:

```just
[arg("bar", long="bar", value="hello")]
foo bar="goodbye":
```

```console
$ just foo
bar=goodbye
$ just foo --bar
bar=hello
```

### `[arg(ARG, help="HELP")]` (1.46.0)

Help string surfaced by `just --usage RECIPE`.

```just
[arg("bar", help="hello")]
foo bar:
```

```console
$ just --usage foo
Usage: just foo bar

Arguments:
  bar hello
```

### Stacking arg attributes

Each `[arg]` configures one parameter. Stack multiple lines for multi-key configuration of one param, or one line per param for several:

```just
[arg("model", long, short="m")]
[arg("stream", long, value="true")]
llm-chat model="haiku" stream="false" +prompt="":
    ...
```

## `[confirm]` / `[confirm(PROMPT)]`

Require terminal confirmation before running. `--yes` skips all confirmations. Recipes that *depend on* a confirmed recipe will not run if the dep is declined.

```just
[confirm]
delete-all:
    rm -rf *

[confirm("Are you sure you want to delete everything?")]
delete-everything:
    rm -rf *
```

The prompt may be an expression (1.49.0+) referencing assignments or arguments:

```just
[confirm("Deploy to " + env + "?")]
deploy env:
    echo 'Deploying to {{env}}...'
```

## `[default]`

When `just` is invoked without a recipe name, it normally runs the first recipe in the file. `[default]` overrides that — the recipe with `[default]` runs instead.

```just
build:
    cargo build

[default]
list:
    @just --list
```

## `[doc]` / `[doc(DOC)]`

Comments immediately preceding a recipe are shown in `just --list`. `[doc(...)]` overrides the auto-derived comment; bare `[doc]` suppresses it. Applies to modules and recipes.

```just
# This comment won't appear
[doc('Build stuff')]
build:
    ./bin/build

# This one won't either
[doc]
test:
    ./bin/test
```

```console
$ just --list
Available recipes:
    build # Build stuff
    test
```

## `[env(VAR, VALUE)]`

Set an environment variable for one recipe. `VALUE` may be an expression (1.49.0+) referencing other vars/args.

```just
[env("RUST_BACKTRACE", "1")]
test:
    cargo test
```

## `[extension(EXT)]`

Set the file extension that `just` uses when writing a shebang/script recipe body to a temp file. `EXT` should include a leading dot.

```just
[extension(".sh")]
build:
    #!/usr/bin/env bash
    ...
```

Useful when an interpreter requires a specific extension to dispatch correctly (e.g., `.ts` for `ts-node`).

## `[exit-message]`

Print the standard `error: Recipe X failed on line Y…` message when a recipe fails, even when `set no-exit-message` is on at the module level.

## `[group(NAME)]`

Place a recipe (or module) under a named group in `--list` output. A recipe may have multiple `[group(...)]` attributes — it appears in each group.

```just
[group('lint')]
js-lint:
    echo 'Running JS linter…'

[group('rust recipes')]
[group('lint')]
rust-lint:
    echo 'Running Rust linter…'

[group('lint')]
cpp-lint:
    echo 'Running C++ linter…'

# not in any group
email-everyone:
    echo 'Sending mass email…'
```

```console
$ just --list
Available recipes:
    email-everyone # not in any group

    [lint]
    cpp-lint
    js-lint
    rust-lint

    [rust recipes]
    rust-lint

$ just --groups
Recipe groups:
  lint
  rust recipes
```

## `[metadata(...)]`

Attach lists of metadata strings to a recipe. Surfaced via `just --dump --dump-format json`.

```just
[metadata("hello", "goodbye")]
foo:
```

## `[no-cd]`

By default, `just` `cd`s into the directory containing the justfile before running each recipe. `[no-cd]` opts out — the recipe runs from the user's invocation cwd. Use this for recipes operating on filesystem args supplied by the user.

```just
[no-cd]
commit file:
    git add {{file}}
    git commit
```

```just
@foo:
    pwd

[no-cd]
@bar:
    pwd
```

```console
$ cd subdir
$ just foo
/
$ just bar
/subdir
```

## `[no-exit-message]`

Suppress `error: Recipe X failed on line Y with exit code Z` output. Useful for wrapper recipes that pass through to another command — let *that* command's own error message stand on its own.

```just
git *args:
    @git {{args}}
```

```console
$ just git status
fatal: not a git repository (or any of the parent directories): .git
error: Recipe `git` failed on line 2 with exit code 128
```

```just
[no-exit-message]
git *args:
    @git {{args}}
```

```console
$ just git status
fatal: not a git repository (or any of the parent directories): .git
```

Module-wide: `set no-exit-message` (1.39.0+).

## `[no-quiet]`

Override `set quiet` for one recipe — always echo this recipe's lines.

```just
set quiet

foo:
    echo "This is quiet"

[no-quiet]
foo2:
    echo "This is not quiet"
```

## `[parallel]`

Run a recipe's dependencies concurrently rather than sequentially.

```just
[parallel]
main: foo bar baz

foo:
    sleep 1

bar:
    sleep 1

baz:
    sleep 1
```

`main`'s body runs after *all* parallel deps complete.

## `[positional-arguments]`

Per-recipe equivalent of `set positional-arguments`. Recipe args become `$1`, `$2`, … in the shell instead of `{{name}}` substitutions. For linewise recipes, `$0` is the recipe name.

```just
[positional-arguments]
@foo bar:
    echo $0
    echo $1
```

`"$@"` expands to all args (sh-compatible shells). Note PowerShell handles positional args differently — `set shell := ['pwsh.exe', '-CommandWithArgs']` (PS 7.4+) is required for parity.

## `[private]`

Hide a recipe (or alias) from `--list` / `--summary` without renaming it. (Recipes whose name starts with `_` are also hidden — `[private]` lets you keep the public name.)

```just
[private]
foo:

[private]
alias b := bar

bar:
```

```console
$ just --list
Available recipes:
    bar
```

## `[script]` / `[script(COMMAND)]`

Execute the recipe body as a script through a specified interpreter. Avoids three classes of shebang-recipe issues:

1. The need for `cygpath` translation on Windows
2. The need for `/usr/bin/env` portability gymnastics
3. Inconsistent shebang-line splitting across Unix OSes

Empty `[script]` (1.33.0) uses `set script-interpreter := […]` (default `['sh', '-eu']`). Note: this is *not* `set shell` — script recipes deliberately ignore the shell setting so script-style and line-by-line recipes can use different interpreters.

```just
set script-interpreter := ['uv', 'run', '--script']

[script]
hello:
    print("Hello from Python!")

[script]
goodbye:
    # /// script
    # requires-python = ">=3.11"
    # dependencies=["sh"]
    # ///
    import sh
    print(sh.echo("Goodbye from Python!"), end='')
```

`[script(COMMAND)]` (1.32.0) is the explicit form — interpret with this command:

```just
[script("python3 -c")]
inline-py:
    import sys; print(sys.version)
```

`just` evaluates the body, writes it to a temp file, and passes the path to `COMMAND` as a final argument.

## `[working-directory(PATH)]`

Set the recipe's cwd. `PATH` is interpreted relative to the default working directory (the justfile's dir).

```just
[working-directory: 'bar']
@foo:
    pwd
```

```console
$ pwd
/home/bob
$ just foo
/home/bob/bar
```

Higher precedence than `set working-directory := …` for one recipe. Mutually exclusive with `[no-cd]` for the same recipe.

## OS Configuration Gates

OS-gate attributes are *configuration* attributes — they conditionally enable a recipe based on the current OS. By default, recipes are always enabled. A recipe with one or more OS gates is enabled only when *one* of those configurations matches the current platform.

| Attribute | Since | Matches when |
|-----------|------:|--------------|
| `[android]` | 1.50.0 | `os() == "android"` |
| `[dragonfly]` | 1.47.0 | `os() == "dragonfly"` |
| `[freebsd]` | 1.47.0 | `os() == "freebsd"` |
| `[linux]` | 1.8.0 | `os() == "linux"` |
| `[macos]` | 1.8.0 | `os() == "macos"` |
| `[netbsd]` | 1.47.0 | `os() == "netbsd"` |
| `[openbsd]` | 1.38.0 | `os() == "openbsd"` |
| `[unix]` | 1.8.0 | `os_family() == "unix"` (includes macOS) |
| `[windows]` | 1.8.0 | `os() == "windows"` |

Pair same-named recipes with different gates for cross-platform fallthrough:

```just
[unix]
run:
    cc main.c
    ./a.out

[windows]
run:
    cl main.c
    main.exe
```

`just run` selects the right body by platform.
