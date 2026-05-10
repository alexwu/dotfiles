# Justfile Settings — Reference

`set X` directives configure justfile interpretation and execution. Each setting may be specified at most once, anywhere in the justfile.

Source: <https://just.systems/man/en/settings.html>

```just
set shell := ["zsh", "-cu"]

foo:
  # this line will be run as `zsh -cu 'ls **/*.txt'`
  ls **/*.txt
```

## Table of Contents

- [Full settings table](#full-settings-table)
- [Boolean syntax](#boolean-syntax)
- [Non-boolean values and the no-backticks rule](#non-boolean-values-and-the-no-backticks-rule)
- [Settings do not propagate across modules](#settings-do-not-propagate-across-modules)
- [Shell precedence](#shell-precedence)
- [Common shell choices](#common-shell-choices)
- [Per-setting reference](#per-setting-reference)
  - [`set allow-duplicate-recipes`](#set-allow-duplicate-recipes)
  - [`set allow-duplicate-variables`](#set-allow-duplicate-variables)
  - [`set dotenv-load` / `dotenv-filename` / `dotenv-path` / `dotenv-required` / `dotenv-override`](#dotenv-loading)
  - [`set export`](#set-export)
  - [`set fallback`](#set-fallback)
  - [`set ignore-comments`](#set-ignore-comments)
  - [`set lazy` (1.47.0+)](#set-lazy-1470)
  - [`set no-exit-message` (1.39.0+)](#set-no-exit-message-1390)
  - [`set positional-arguments`](#set-positional-arguments)
  - [`set quiet`](#set-quiet)
  - [`set script-interpreter` (1.33.0+)](#set-script-interpreter-1330)
  - [`set shell`](#set-shell)
  - [`set tempdir`](#set-tempdir)
  - [`set unstable` (1.31.0+)](#set-unstable-1310)
  - [`set windows-powershell` (deprecated)](#set-windows-powershell-deprecated)
  - [`set windows-shell`](#set-windows-shell)
  - [`set working-directory` (1.33.0+)](#set-working-directory-1330)

---

## Full settings table

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `allow-duplicate-recipes` | bool | `false` | Later recipes override earlier ones with the same name |
| `allow-duplicate-variables` | bool | `false` | Later vars override earlier ones with the same name |
| `dotenv-filename` | string | — | Custom `.env` filename to load |
| `dotenv-load` | bool | `false` | Load `.env` if present |
| `dotenv-override` | bool | `false` | `.env` values override pre-existing env vars |
| `dotenv-path` | string | — | Specific path to load (overrides `dotenv-filename`) |
| `dotenv-required` | bool | `false` | Error if `.env` not found |
| `export` | bool | `false` | Export all `:=` assignments as env vars |
| `fallback` | bool | `false` | If recipe not found, search parent justfiles |
| `ignore-comments` | bool | `false` | Skip recipe lines starting with `#` (don't pass them to the shell) |
| `lazy` (1.47.0+) | bool | `false` | Don't evaluate unused variables |
| `no-exit-message` (1.39.0+) | bool | `false` | Module-wide `[no-exit-message]` |
| `positional-arguments` | bool | `false` | Pass recipe args as positional `$1`/`$2`/`$@` to commands |
| `quiet` | bool | `false` | Suppress recipe-line echo |
| `script-interpreter` (1.33.0+) | `[CMD, ARGS…]` | `['sh', '-eu']` | Interpreter for empty `[script]` recipes |
| `shell` | `[CMD, ARGS…]` | — | Shell for line-by-line recipes and backticks (default `sh -cu`) |
| `tempdir` | string | — | Where to write shebang/script recipe temp files |
| `unstable` (1.31.0+) | bool | `false` | Enable unstable features (`&&`/`\|\|`, `which()`, user-defined functions) |
| `windows-powershell` | bool | `false` | (Deprecated) use legacy `powershell.exe`. Use `windows-shell` instead |
| `windows-shell` | `[CMD, ARGS…]` | — | Shell on Windows (higher precedence than `shell`) |
| `working-directory` (1.33.0+) | string | — | Module-wide cwd override (relative or absolute) |

## Boolean syntax

Boolean settings — these are equivalent:

```just
set NAME
set NAME := true
```

## Non-boolean values and the no-backticks rule

Non-boolean settings can be strings or expressions (1.46.0+), with the caveat that those expressions can't contain backticks or function calls (because settings configure the very mechanisms backticks/functions depend on).

## Settings do not propagate across modules

`set` directives configure the module they appear in. Submodules don't automatically inherit parent settings — each module declares its own. The exception: dotenv files loaded in parent modules *are* inherited by submodules (1.49.0+), and submodules may override parent values. See [`modules.md`](modules.md) for full per-module semantics.

## Shell precedence

Source: <https://just.systems/man/en/configuring-the-shell.html>

From highest to lowest:

1. `--shell` / `--shell-arg` CLI options (override everything)
2. `set windows-shell := [...]`
3. `set windows-powershell` (deprecated)
4. `set shell := [...]`

This lets you set `shell` for non-Windows and `windows-shell` for Windows in the same justfile.

## Common shell choices

```just
set shell := ["bash", "-uc"]
set shell := ["nu", "-c"]
set shell := ['nu', '-m', 'light', '-c']    # Nushell, light table mode
```

Same pattern works for `zsh`, `fish`, `python3`, etc. — `[INTERPRETER, FLAG]`.

---

## Per-setting reference

### `set allow-duplicate-recipes`

Last definition wins instead of erroring on duplicate recipe names.

```just
set allow-duplicate-recipes

@foo:
  echo foo

@foo:
  echo bar    # `just foo` prints `bar`
```

### `set allow-duplicate-variables`

Last definition wins instead of erroring on duplicate variable names.

```just
set allow-duplicate-variables

a := "foo"
a := "bar"    # {{a}} expands to `bar`
```

### Dotenv loading

If any of `dotenv-load`, `dotenv-filename`, `dotenv-path`, `dotenv-required` are set, `just` tries to load env vars from a file. Loaded values become *environment* variables (not `just` variables), so they're accessed via `$VAR_NAME` in recipes and backticks — *not* `{{VAR_NAME}}`.

Resolution rules:

- If `dotenv-path` is set, `just` looks for a file at the given path, which may be absolute or relative to the working directory. **Errors** if not present.
- If `dotenv-filename` is set, `just` looks for a file at the given path, relative to the working directory **and each of its ancestors**.
- If `dotenv-filename` is not set, but `dotenv-load` or `dotenv-required` are set, `just` looks for a file named `.env`, relative to the working directory and each of its ancestors.
- `dotenv-path` is checked **only relative to the working directory**, whereas `dotenv-filename` is checked relative to the working directory and **each ancestor**.
- It is not an error if an environment file is not found, unless `dotenv-required` is set.
- If `dotenv-override` is set, variables from the environment file will override existing environment variables.

```sh
# .env
DATABASE_ADDRESS=localhost:6379
```

```just
set dotenv-load

serve:
    ./server --database $DATABASE_ADDRESS
```

CLI override: `--dotenv-path PATH` (short `-E PATH`).

Variables in environment files loaded in parent modules are inherited by submodules. Environment files are loaded in submodules (1.49.0+) and may override variables defined in parent module environment files. See [`modules.md`](modules.md).

### `set export`

Exports all `just` variables (and recipe parameters) as environment variables. Defaults to `false`.

```just
set export

a := "hello"

@foo b:
  echo $a    # hello
  echo $b    # (recipe arg)
```

Note: under `set lazy`, exported variables are **always** evaluated — `just` cannot determine when an exported variable is read by the shell, so laziness can't apply.

### `set fallback`

Source: <https://just.systems/man/en/fallback-to-parent-justfiles.html>

If a recipe is not found in a `justfile` and the `fallback` setting is set, `just` walks up the directory tree looking for parent justfiles. It stops at the first parent without `set fallback`.

```just
set fallback
foo:
  echo foo
```

`just bar` (defined only in a parent justfile) prints `Trying ../justfile` and runs the parent's `bar`.

### `set ignore-comments`

Skips recipe lines starting with `#` instead of passing them to the shell. Useful with PowerShell, Nushell, and other interpreters that treat `#` differently than `sh`.

```just
set ignore-comments
```

### `set lazy` (1.47.0+)

The `lazy` setting causes the evaluator to skip evaluating unused variables. This can be beneficial when a `justfile` contains variables that are expensive to evaluate but only sometimes used.

```just
set lazy

token := `expensive-script-to-get-credentials`

foo:
    curl -H "Authorization: Bearer {{ token }}" https://example.com/foo

bar:
    cargo test
```

Without `set lazy`, `bar` would still run the expensive `token` backtick. With it, only recipes that use `{{token}}` pay the cost.

Caveat: because `just` cannot determine when exported variables are used, assignments with `export` and assignments in a module with `set export` will always be evaluated.

### `set no-exit-message` (1.39.0+)

Module-wide version of the `[no-exit-message]` attribute — suppresses the `error: Recipe X failed on line Y with exit code Z` summary that `just` normally prints when a recipe exits non-zero.

See also: [`attributes.md#no-exit-message`](attributes.md#no-exit-message) for the per-recipe equivalent and the `[exit-message]` override that re-enables messaging on a single recipe.

### `set positional-arguments`

Passes recipe arguments as positional `$1`/`$2`/`$@` to recipe lines. For linewise recipes, `$0` is the recipe name.

```just
set positional-arguments

@foo bar:
    echo $0    # foo
    echo $1    # (first arg)
```

In `sh`-compatible shells (`bash`, `zsh`), `"$@"` expands to all positional args from `$1`, preserving whitespace-bearing args as if double-quoted (equivalent to `"$1" "$2" …`). Empty when there are no args.

With PowerShell, this needs `-CommandWithArgs` (PS 7.4+):

```just
set shell := ['pwsh.exe', '-CommandWithArgs']
set positional-arguments

print-args a b c:
    Write-Output @($args[1..($args.Count - 1)])
```

PowerShell does not handle positional arguments the same way as other shells, so turning on positional arguments will likely break recipes that use PowerShell unless the `-CommandWithArgs` workaround is used.

See also: [`attributes.md#positional-arguments`](attributes.md#positional-arguments) for the per-recipe `[positional-arguments]` attribute (1.29.0+), and [`expressions.md#6-positional-arguments-mode-and-avoiding-argument-splitting`](expressions.md#6-positional-arguments-mode-and-avoiding-argument-splitting) for the full positional-args reference.

### `set quiet`

Source: <https://just.systems/man/en/quiet-recipes.html>

Suppresses recipe-line echo for every recipe in the justfile.

```just
set quiet

foo:
  echo "This is quiet"
```

Override per-recipe with the `[no-quiet]` attribute. See [`attributes.md#no-quiet`](attributes.md#no-quiet).

### `set script-interpreter` (1.33.0+)

`[COMMAND, ARGS…]`, default `['sh', '-eu']`. Set the command used to invoke recipes with an empty `[script]` attribute.

Recipes with an empty `[script]` attribute are executed with the value of `set script-interpreter := [...]`, defaulting to `sh -eu`, and *not* the value of `set shell`.

See [`attributes.md#script--scriptcommand`](attributes.md#script--scriptcommand) for the `[script]` and `[script(COMMAND)]` attributes, and [`scripts.md`](scripts.md) for full script-recipe semantics (temp file handling, shebang interaction, error rules).

### `set shell`

The `shell` setting controls the command used to invoke recipe lines and backticks. Shebang recipes are unaffected. The default shell is `sh -cu`.

```just
# use python3 to execute recipe lines and backticks
set shell := ["python3", "-c"]

# use print to capture result of evaluation
foos := `print("foo" * 4)`

foo:
  print("Snake snake snake snake.")
  print("{{foos}}")
```

`just` passes the command to be executed as an argument. Many shells will need an additional flag, often `-c`, to make them evaluate the first argument.

### `set tempdir`

Per-module setting of where `just` writes temporary files for script and shebang recipes.

Tempdir resolution precedence:

- Globally with the `--tempdir` command-line option or the `JUST_TEMPDIR` environment variable (1.41.0+).
- On a per-module basis with the `tempdir` setting.

See [`scripts.md`](scripts.md) for the full temp file rules used by shebang and `[script]` recipes.

### `set unstable` (1.31.0+)

Enable unstable features (e.g., `&&`/`||` operators, `which()`, `env() || default`, user-defined functions).

```just
set unstable
```

Unstable features may change behavior or be removed without notice across `just` releases — if you rely on one, pin your `just` version.

### `set windows-powershell` (deprecated)

`just` uses `sh` on Windows by default. To use `powershell.exe` instead, set `windows-powershell` to true.

```just
set windows-powershell := true

hello:
  Write-Host "Hello, world!"
```

`set windows-powershell` uses the legacy `powershell.exe` binary, and is no longer recommended. See `windows-shell` below for a more flexible way to control which shell is used on Windows.

### `set windows-shell`

`just` uses `sh` on Windows by default. To use a different shell on Windows, use `windows-shell`:

```just
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

hello:
  Write-Host "Hello, world!"
```

See [powershell.just](https://github.com/casey/just/blob/master/examples/powershell.just) for a justfile that uses PowerShell on all platforms.

### `set working-directory` (1.33.0+)

```just
set working-directory := 'bar'

@foo:
  pwd
```

```console
$ pwd
/home/bob
$ just foo
/home/bob/bar
```

The argument may be absolute or relative; if relative, it's interpreted relative to the default working directory. The setting applies module-wide.

See also: [`attributes.md#working-directorypath`](attributes.md#working-directorypath) for the per-recipe `[working-directory(PATH)]` attribute (1.38.0+) — when both are set, the attribute wins on the recipes that carry it.
