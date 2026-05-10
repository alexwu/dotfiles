---
name: writing-justfiles
description: Writes idiomatic justfiles using just's native attribute system, parameters, dependencies, settings, modules, imports, the full library of 71 built-in functions, 32 attributes, and 29 constants. Use whenever editing or creating a `justfile`, `.justfile`, `Justfile`, or any file under `~/.config/just/`; whenever the user mentions "just recipe", "global justfile", "justfile attribute", "just task", "just function", "just constant", "casey/just", "command runner"; or any time the user asks for a task runner that is explicitly NOT `make`, `mise`, `npm run`, or `task`. Triggers on terse asks too — "add a recipe that…", "write a just recipe to…", "make a justfile for X" — without waiting for the user to name `just` outright. If the user is already in a directory containing a `justfile` and asks for a project-level command shortcut, this skill applies.
---

# Writing Justfiles

`just` (https://github.com/casey/just) is a command runner with a `make`-flavored syntax minus the build-system semantics. This skill is a router: it shows the shape of just's surface area and points you at the deep references for every dimension. Don't preload the references — load only the ones the current task touches.

If the user doesn't have `just` installed, point them at `brew install just` (macOS), `cargo install just`, or `https://just.systems/man/en/installation.html`.

## When this skill is loaded

| What you need | Where to look |
|---------------|---------------|
| Recipe shape — params, deps, sigils, aliases, listing, working-dir, naming, indentation, multi-line, sharing-env, `[confirm]` semantics | [`references/recipes.md`](references/recipes.md) |
| Expressions — variables, strings, interpolation, brace escaping, conditionals, command eval, positional-args mode, user-defined fns | [`references/expressions.md`](references/expressions.md) |
| Every attribute (all 32) with forms and examples | [`references/attributes.md`](references/attributes.md) |
| Every built-in function (all 71) — signatures, behavior, examples | [`references/built-in-functions.md`](references/built-in-functions.md) |
| The 29 predefined constants (paths, hex alphabets, ANSI escapes) | [`references/constants.md`](references/constants.md) |
| All `set X` settings — full table + per-setting prose | [`references/settings.md`](references/settings.md) |
| `mod` and `import` — namespaces vs. mixins, search rules | [`references/modules.md`](references/modules.md) |
| Shebang recipes, `[script]`, temp-file rules | [`references/scripts.md`](references/scripts.md) |
| `error()`, `assert()`, `[no-exit-message]`, `[exit-message]` | [`references/errors.md`](references/errors.md) |
| CLI flags, global justfiles, `--fmt` / `--evaluate` / `--dump`, signal handling | [`references/cli.md`](references/cli.md) |
| Cross-cutting idioms from real justfiles + anti-patterns table | [`references/idioms.md`](references/idioms.md) |

## Quickstart

A justfile is a file named `justfile`, `.justfile`, `Justfile`, or `JUSTFILE` (lookup is case-insensitive). It contains recipes — named blocks of shell commands. `just` invoked with no args runs the first recipe (or the recipe annotated `[default]`); `just <name>` runs a named recipe.

```just
default:
    @just --list

build:
    cargo build --release

test: build
    cargo test
```

`just` searches the cwd and parents for a justfile. `just -g` (global) loads the user-level justfile from `$XDG_CONFIG_HOME/just/justfile`, `~/.config/just/justfile`, `~/justfile`, or `~/.justfile` — first hit wins. Alex aliases `J = just -g`.

Lines prefixed `@` are not echoed before execution. Recipes prefixed `@` (the recipe name itself, not a line) flip the per-line default — every line is silent unless explicitly echoed with no `@`.

## Recipe Parameters

```just
build target:
    cargo build --release --target {{target}}
```

`just build x86_64-unknown-linux-musl` invokes the recipe with `target=x86_64-unknown-linux-musl`.

### Default values

```just
arch := "wasm"

test target tests=arch:
    ./test --tests {{tests}} {{target}}
```

Default values are arbitrary expressions. Expressions using `+`, `&&`, `||`, or `/` must be parenthesized:

```just
test triple=(arch + "-unknown-unknown") input=(arch / "input.dat"):
    ./test {{triple}}
```

### Variadic parameters — `+` and `*`

The last parameter may be variadic. `+` requires at least one arg; `*` accepts zero or more. Both expand to space-separated strings.

```just
backup +FILES:
    scp {{FILES}} me@server.com:

commit MESSAGE *FLAGS:
    git commit {{FLAGS}} -m "{{MESSAGE}}"
```

Variadic parameters can carry defaults — overridden by command-line args:

```just
test +FLAGS='-q':
    cargo test {{FLAGS}}
```

### Exporting parameters as env vars — `$name`

Prefix a parameter with `$` to export it as an environment variable for the recipe's shell:

```just
test $RUST_BACKTRACE="1":
    cargo test
```

### Argument-splitting hazards

`{{name}}` interpolation pastes the parameter value directly into the recipe line. If the value contains spaces, the shell will re-split it:

```just
# Wrong — `lynx` sees three args.
search QUERY:
    lynx https://www.google.com/?q={{QUERY}}

# Right — quote the interpolation.
search QUERY:
    lynx 'https://www.google.com/?q={{QUERY}}'
```

Three coping strategies for whitespace-bearing args: quote the interpolation as above; use `set positional-arguments` and reference `"$1"` instead of `{{QUERY}}`; or export the parameter (`$QUERY`) and use `"$QUERY"`.

→ see `references/recipes.md` for the full reference.

## Recipe Dependencies

Dependencies run before the recipe that lists them. Within a single invocation, a recipe with the same arguments runs only once.

```just
build:
    cargo build

test: build
    cargo test
```

Dependencies can take arguments — `deploy: (build "x86_64-unknown-linux-musl")`. Subsequent dependencies (run *after* the body, in declaration order) use `&&`:

```just
build: setup && cleanup
    cargo build
```

`[parallel]` on a recipe runs all of its dependencies concurrently before the body. Without it, deps run sequentially in declaration order.

→ see `references/recipes.md` for the full reference.

## Variables and Assignments

```just
LLAMA_SWAP := "http://localhost:8000"
TARGET    := "x86_64-unknown-linux-musl"

build:
    cargo build --target {{TARGET}}
```

Variables can be computed via backticks (run at justfile-load time, not recipe-time):

```just
tmpdir := `mktemp -d`
git_sha := `git rev-parse --short HEAD`
```

`export NAME := "..."` exports one assignment; `set export` exports them all; `unexport NAME` removes one from the recipe environment.

→ see `references/expressions.md` for the full reference.

## String Interpolation and Brace Escaping

Inside recipe bodies, `{{ expr }}` is interpolated:

```just
publish:
    scp {{tarball}} me@server.com:release/
```

To emit a literal `{{` in a recipe body, write `{{{{`. The closing `}}` is matched, so `}}}}` produces `}}`. Real example from Alex's global justfile (calling `lumis themes generate` with a Lua script that contains a Lua-table literal `{ ... }` inside a `vim.pack.add({...})` call where the curly braces would otherwise be eaten by `just`):

```just
lumis-regen-snazzy:
    lumis themes generate \
        -c snazzy \
        -s 'vim.pack.add({{{{ src = "https://github.com/rktjmp/lush.nvim" }}}}, ...)'
```

`{{{{ src = "..." }}}}` reaches the shell as the literal string `{{ src = "..." }}`.

`+` concatenates. `/` is a path-join that always uses `/` (even on Windows). `&&` and `||` (short-circuit, unstable) require `set unstable`.

→ see `references/expressions.md` for the full reference.

## Attributes

Attributes are decorators on recipes (and modules/aliases). Multiple attributes can stack on separate lines or be comma-separated `[a, b]`. Single-arg attributes accept colon syntax `[group: 'name']`. The high-frequency set:

| Attribute | Purpose |
|-----------|---------|
| `[group("NAME")]` | Group a recipe under a heading in `just --list` / `just --groups` |
| `[doc("TEXT")]` | One-line description shown in `just --list` (also applies to `mod`) |
| `[confirm]` / `[confirm("PROMPT")]` | Ask y/n before running; prompt may be an expression |
| `[no-cd]` | Don't cd into the justfile's directory — use cwd of invocation |
| `[private]` | Hide from `--list` / `--summary` (same as `_` name prefix) |
| `[arg(NAME, …)]` | Flagify a parameter (`long`, `short`, `value`, `pattern`, `help`) |
| `[script]` / `[script("INTERP")]` | Run body via interpreter — sidesteps shebang/cygpath issues |
| `[parallel]` | Run all dependencies concurrently |
| `[macos]` / `[linux]` / `[windows]` / `[unix]` (etc.) | OS gates; multiple = OR |
| `[no-exit-message]` / `[exit-message]` | Suppress / re-enable `error: Recipe X failed…` |
| `[positional-arguments]` | Per-recipe `set positional-arguments` |
| `[working-directory("PATH")]` | Run from a specific dir |
| `[default]` | Designate the recipe `just` (no args) runs |
| `[env("VAR", "VALUE")]` | Set an env var for one recipe |

→ see `references/attributes.md` for all 32 attributes with full forms and examples.

## Settings — `set X`

Top of the justfile. Each setting may appear at most once.

| Setting | Purpose |
|---------|---------|
| `set shell := [CMD, ARGS…]` | Shell for line-by-line recipes (default `sh -cu`); doesn't affect shebang recipes |
| `set positional-arguments` | Recipe args become `$1`/`$2`/`$@` instead of `{{name}}` substitutions |
| `set dotenv-load` | Load a `.env` file into the recipe environment |
| `set unstable` | Enable `&&`/`||`, `which()`, user-defined functions |

→ see `references/settings.md` for the full settings table (`export`, `quiet`, `fallback`, `ignore-comments`, `lazy`, `script-interpreter`, `tempdir`, `working-directory`, `windows-shell`, dotenv variants, etc.).

## Constants

29 predefined constants for paths, hex alphabets, and ANSI escape sequences. Examples:

```just
random-token := choose("32", HEX)

@scary:
    echo '{{BOLD + RED}}OH NO{{NORMAL}}'

cross-platform:
    echo "delim:{{PATH_SEP}} listsep:{{PATH_VAR_SEP}}"
```

`PATH_SEP` and `PATH_VAR_SEP` differ on Windows (`\` and `;`). All ANSI-color constants come paired with `BG_*` background variants. Always close a styled string with `{{NORMAL}}` to reset.

→ see `references/constants.md` for the full table.

## Built-in Functions

71 functions across system info, env, paths, filesystem, strings/casing, hashing, datetime, semver, and ANSI styling. The ones you'll reach for most: `quote()` (always wrap user-supplied params before interpolating into bash), `env(key, default)`, `shell(cmd, args…)`, `os()` / `os_family()` (cross-platform branches), `path_exists()` and `read()` (file-driven workflows), `home_directory()` / `config_directory()` (XDG-aware paths). Functions ending in `_directory` may be abbreviated to `_dir`.

→ see `references/built-in-functions.md` for all 71 with signatures, behavior, and examples.

## Modules and Imports

```just
mod docker
mod nested 'subprojects/api/justfile'
mod? optional-tasks   # missing file is fine

import 'common.just'
import? 'local-overrides.just'
```

`mod foo` searches `foo.just`, `foo/mod.just`, `foo/justfile`, `foo/.justfile`. Submodule recipes are addressed `just docker::build` or `just docker build` and run with the submodule's source dir as cwd (unless `[no-cd]`).

`import` splices the imported file's recipes/variables into the current module. Top-level definitions override imported ones. Use `import` for mixin-style sharing within one module; use `mod` for namespaced separation.

→ see `references/modules.md` for the full reference.

## Idiomatic Patterns

Drawn from real justfiles in this user's setup. See `references/idioms.md` for the full prose, code, and the anti-patterns table.

- **Default recipe = `@just --list`** — running `just` with no args prints the menu.
- **Shebang recipes for multi-line bash** with `set -euo pipefail` — plain recipes lose `cd`/`if`/vars across lines.
- **Always `quote()` user-supplied params before bash** — the only safe way to interpolate `+prompt=""` style args.
- **Group + doc on every recipe** — makes `just -l` self-documenting.
- **`[arg]` to expose params as flags** — beats awkward positional defaults like `just deploy "" "" verbose`.
- **`[no-cd]` for any recipe taking a path argument** — the user names paths relative to *their* shell, not the justfile's.
- **`[confirm]` for any destructive `launchctl` / `rm` / `docker prune`** — cheap; use the expression form to mention what's affected.

→ see `references/idioms.md` for full examples and the anti-patterns table.

## Verifying your output

Before declaring a justfile change done:
1. `just --fmt --check` — confirms canonical formatting (will exit 1 + diff if not).
2. `just --list` — confirms recipes appear under their groups with their docs.
3. `just --evaluate` — prints all module variables; useful for catching unintended shell expansion in `:=` assignments.
4. For the recipe you just wrote, `just <name> --dry-run` if the user has set up dry-run flags, OR run the recipe end-to-end if it's safe to do so.

For a recipe in the user's *global* justfile (`~/.config/just/justfile`), `J -l` is the verification.
