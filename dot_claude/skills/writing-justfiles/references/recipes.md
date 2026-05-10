# Justfile Recipes — Reference

The structural mechanics of `just` recipes themselves: parameters, dependencies, sigils, aliases, listing/visibility, working directory, indentation, multi-line layout, and naming. Attribute *syntax* lives in `attributes.md` — when an attribute is mentioned here, behaviour is summarised and the reader is linked back. Expression-language details (interpolation, operators, conditionals, user fns), settings, modules, scripts, errors, and CLI options live in their own files; see SKILL.md for the routing table.

## Table of Contents

1. [Recipe parameters (deep)](#1-recipe-parameters-deep)
2. [Recipe dependencies](#2-recipe-dependencies)
3. [Working directory](#3-working-directory)
4. [Listing recipes — `--list`, `--summary`, `--groups`](#4-listing-recipes----list---summary---groups)
5. [Sigils — `-`, `@`, `?`](#5-sigils-----)
6. [Aliases](#6-aliases)
7. [Confirmation behaviour](#7-confirmation-behaviour)
8. [Indentation rules](#8-indentation-rules)
9. [Multi-line constructs](#9-multi-line-constructs)
10. [Sharing env between recipes](#10-sharing-env-between-recipes)
11. [Recipe naming rules](#11-recipe-naming-rules)

---

## 1. Recipe parameters (deep)

Source: <https://just.systems/man/en/recipe-parameters.html>

Recipes accept positional parameters declared after the recipe name. SKILL.md covers the basics (positional, defaults, variadic `+`/`*`); this section adds the corner cases.

### Default values are arbitrary expressions

Expressions involving `+`, `&&`, `||`, or `/` must be parenthesized when used as a default:

```just
arch := "wasm"

test triple=(arch + "-unknown-unknown") input=(arch / "input.dat"):
    ./test {{triple}}
```

### Variadic with default

```just
test +FLAGS='-q':
    cargo test {{FLAGS}}
```

`+FLAGS='-q'` accepts one or more args, defaulting to `-q` if none. (`*FLAGS` accepts zero or more.)

### Exporting a parameter — `$name`

Prefixing a parameter with `$` exports it as an env var in the recipe shell, in addition to `{{name}}`. One of three argument-splitting strategies — full treatment in `expressions.md` (Avoiding Argument Splitting):

```just
foo $argument:
    touch "$argument"
```

### Quoting hazards

Recipe parameters interpolate as bare text into recipe-line shell — arguments with whitespace or shell metacharacters get re-split unless neutralised. Quote the interpolation as a one-liner, or use `quote()` (see `built-in-functions.md`). Full three-strategy comparison (quote / `[positional-arguments]` / exported `$name`) is in `expressions.md`.

### Variables in submodules

Address with `::` — e.g. `just bob::bar=VALUE`, `just --set foo::bar VALUE`, `just --evaluate bob::bar::y`.

### Setting variables in a recipe (you can't, with `:=`)

`just` variables can't be assigned mid-recipe — recipe lines are pure shell. Shell variables are fine but don't survive across lines (each line is a fresh shell):

```just
foo:
    x=hello && echo $x   # works
    y=bye
    echo $y              # broken — y is unset in the new shell
```

Workaround: a shebang recipe (see `scripts.md`).

---

## 2. Recipe dependencies

Source: <https://just.systems/man/en/dependencies.html>

A recipe lists its prior dependencies after the colon: `b: a c d`. Dependencies always run before the recipe body, in the order declared.

### Dependencies with arguments

Use parentheses around a dep with arguments:

```just
release: (build "release")

build target:
    cd {{target}} && make
```

### Deduplication

Within one invocation, a recipe with the same args runs only once:

```just
a:
    @echo A

b: a
    @echo B

c: a
    @echo C
```

`just a a a a a` prints `A` once; `just b c` prints `A B C` (a runs once even though b and c both depend on it). Different args break dedup — `just test foo test bar` (where `test TEST: build`) runs `build` once but the test body twice.

### Subsequent dependencies — `&&`

Run *after* the recipe body, in declaration order. `just b` below prints `A! B! C! D!`:

```just
a:
    echo 'A!'

b: a && c d
    echo 'B!'

c:
    echo 'C!'
d:
    echo 'D!'
```

`just` doesn't support invoking recipes mid-recipe directly — call `just` recursively from a recipe line if needed (assignments are recalculated and command-line args don't propagate).

### Parallel dependencies — `[parallel]`

Source: <https://just.systems/man/en/parallelism.html>

```just
[parallel]
main: foo bar baz

foo:
    sleep 1
bar:
    sleep 1
```

Body of `main` runs after *all* parallel deps complete. See `attributes.md#parallel` for the attribute's syntax forms (target selection, child-process behaviour).

Combine with GNU `parallel` if you need parallelism *within* a recipe body:

```just
fan-out:
    #!/usr/bin/env -S parallel --shebang --ungroup --jobs {{ num_cpus() }}
    echo task 1 start; sleep 3; echo task 1 done
    echo task 2 start; sleep 3; echo task 2 done
```

---

## 3. Working directory

Source: <https://just.systems/man/en/working-directory.html>, <https://just.systems/man/en/changing-the-working-directory-in-a-recipe.html>

Default cwd for a recipe is the justfile's directory. Override mechanisms:

| Mechanism | Scope | Behaviour |
|-----------|-------|-----------|
| `[no-cd]` | one recipe | runs from the *invocation* cwd (don't chdir to the justfile dir). See `attributes.md#no-cd`. |
| `[working-directory(PATH)]` | one recipe | run from `PATH` (relative or absolute). See `attributes.md#working-directorypath`. |
| `set working-directory := 'PATH'` (1.33.0+) | module-wide | applies to every recipe in the module without an attribute override. See `settings.md`. |
| `--working-directory DIR` | CLI override | one invocation. |

### `cd` mid-recipe doesn't persist

Each recipe line is a fresh shell — `cd` on one line does not affect the next. Either chain with `&&` on the same line, or use a shebang recipe so the body runs as one process:

```just
foo:
    cd bar && pwd
```

---

## 4. Listing recipes — `--list`, `--summary`, `--groups`

Source: <https://just.systems/man/en/listing-available-recipes.html>

```console
$ just --list
Available recipes:
    build
    test
    deploy
    lint

$ just --summary
build test deploy lint

$ just --groups
Recipe groups:
    docker
    llm
    tree-sitter
```

`--unsorted` preserves declaration order on either `--list` or `--summary`.

Group membership is set per-recipe via `[group(NAME)]` — see `attributes.md#groupname`. Per-recipe documentation shown in `--list` comes from a leading `# comment` line above the recipe, or from `[doc(DOC)]` — see `attributes.md#doc--docdoc`.

### Submodule listing

`just --list foo bar` and `just --list foo::bar` both list the recipes in the `foo::bar` submodule.

### Default recipe = list

A common pattern: make the first (default) recipe an alias for `--list`, so a bare `just` prints the menu:

```just
default:
    @just --list
```

If `just -f /elsewhere` is in play, use `@just --justfile {{justfile()}} --list` to keep the listing pointed at the right file. When the intended default isn't the first-declared recipe, mark it with `[default]` (see `attributes.md#default`).

### Customising heading and prefix

```console
$ just --list --list-heading $'Cool stuff…\n'
Cool stuff…
    test
    build
```

`--list-prefix STR` overrides the per-line indent; `--list-heading ''` removes the header entirely.

### Hidden recipes

A leading `_` or the `[private]` attribute hides a recipe from `--list` / `--summary` (it's still callable by name). Aliases also support `[private]`. See `attributes.md#private`.

---

## 5. Sigils — `-`, `@`, `?`

Source: <https://just.systems/man/en/sigils.html>, <https://just.systems/man/en/quiet-recipes.html>

Linewise recipe lines may be prefixed with any combination of `-`, `@`, and `?`.

### `@` — toggle echo

```just
foo:
    @echo "This line won't be echoed!"
    echo "This line will be echoed!"
```

A `@` on the recipe name (e.g. `@bar:`) flips the per-line default — every line is silent unless explicitly `@`-prefixed (in which case that line *is* echoed).

### `-` — continue on nonzero exit

```just
# Continues even if `bar` doesn't exist:
foo:
    -rmdir bar
    mkdir bar
    echo 'so much good stuff' > bar/stuff.txt
```

Use sparingly — it swallows real errors. For shebang recipes, prefer `set -e` plus targeted `||true` in bash.

### `?` — stop recipe on exit 1, continue siblings (1.47.0+)

Requires `set guards`. The current recipe stops on exit 1 (other codes still abort); other recipes in the same invocation continue:

```just
set guards

@foo: bar
    echo FOO

@bar:
    ?[[ -f baz ]]
    echo BAR
```

Without `baz`, `just foo` prints only `FOO` (bar's body is skipped after the failing guard). If `set guards` is unset/false, `?` is treated as part of the command.

### Shebang recipes are quiet by default

```just
foo:
    #!/usr/bin/env bash
    echo 'Foo!'
```

A `@` on the recipe name *un-quiets* shebang recipes — `just` will print the body before executing.

---

## 6. Aliases

Source: <https://just.systems/man/en/aliases.html>

```just
alias b := build

build:
    echo 'Building!'
```

`just b` runs `build`. The target may be in a submodule (`alias baz := foo::bar`). Aliases support `[private]` (`attributes.md#private`).

---

## 7. Confirmation behaviour

Source: <https://just.systems/man/en/attributes.html>

Recipes can require interactive confirmation before running. Attribute syntax is in `attributes.md#confirm--confirmprompt`; only behaviour is summarised here.

When a `[confirm]`-gated recipe is declined at the prompt:

- The declined recipe is skipped.
- Any recipe that depended on it is also skipped (dep contract unsatisfied).
- Any recipe **listed after** it on the same invocation is also skipped.

Pass `--yes` (or set `JUST_YES=1`) to auto-confirm every `[confirm]`-gated recipe — useful in scripts and CI.

---

## 8. Indentation rules

Source: <https://just.systems/man/en/indentation.html>

Recipe lines can be indented with spaces or tabs, **not a mix**. A recipe's lines must use the same indent type, but different recipes in the same justfile may differ. Each recipe must indent at least one level past the recipe-name line.

```just
list-space directory:
··#!pwsh
··foreach ($item in $(Get-ChildItem {{directory}} )) {
····echo $item.Name
··}
```

(Schema: `··` = space-indent.) Tab-indent is equally valid as long as a single recipe doesn't mix the two. Indentation nesting (further indent on inner lines) works even when newlines are escaped with `\`.

---

## 9. Multi-line constructs

Source: <https://just.systems/man/en/multi-line-constructs.html>

Plain (line-by-line) recipes evaluate each line in a fresh shell, so multi-line constructs probably won't do what you want:

```just
conditional:
    if true; then
      echo 'True!'
    fi
```

```console
$ just conditional
error: Recipe line has extra leading whitespace
```

Workarounds: (1) one-line form, (2) backslash continuations, (3) shebang recipe (preferred beyond two lines):

```just
conditional:
    if true; then echo 'True!'; fi

conditional:
    if true; then \
      echo 'True!'; \
    fi

conditional:
    #!/usr/bin/env sh
    if true; then
      echo 'True!'
    fi
```

### Backslash continuation in headers

Recipe *headers* (signature lines) and assignments can also be split with `\`:

```just
foo param1 \
    param2='foo' \
    *varparam='': dep1 \
                  (dep2 'foo')
    echo {{param1}} {{param2}} {{varparam}}
```

### Parenthesized expressions can span lines

Works for assignments, default-value expressions, and dependency calls:

```just
abc := ('a' +
        'b'
         + 'c')

bar: (foo
        'Foo'
     )
    echo 'Bar!'
```

### Backslash continuations inside interpolations

```just
recipe:
    echo '{{ \
    "This interpolation " + \
        "has a lot of text." \
    }}'
```

---

## 10. Sharing env between recipes

Source: <https://just.systems/man/en/sharing-environment-variables-between-recipes.html>

Each recipe line is a fresh shell — there's no way to *share* shell env vars between recipes. For tools needing a long-lived env (Python venv, Conda), invoke the env's binaries directly:

```just
venv:
    [ -d foo ] || python3 -m venv foo

run: venv
    ./foo/bin/python3 main.py
```

For just-level env vars per-recipe, see `[env(NAME, VALUE)]` (`attributes.md#envvar-value`). For exporting `:=` assignments wholesale, see `set export` in `settings.md`.

---

## 11. Recipe naming rules

Source: <https://just.systems/man/en/quick-start.html>, <https://just.systems/man/en/listing-available-recipes.html>, <https://just.systems/man/en/private-recipes.html>

- Recipe names use letters, digits, `-`, and `_`. Convention is `kebab-case`.
- A leading `_` marks the recipe private (hidden from `--list`/`--summary`). Equivalent to `[private]` (`attributes.md#private`).
- The justfile filename is searched case-insensitively: `justfile` / `Justfile` / `JUSTFILE` / `JuStFiLe` / `.justfile` all work.
- Recipes execute in the order given on the command line; deps run before dependents; same-args runs dedup within an invocation.
