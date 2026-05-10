# Justfile Shebang and Script Recipes — Reference

Recipes whose body executes as a single script — written to a temp file and handed to an interpreter — instead of being evaluated line-by-line. Two flavors:

- **Shebang recipes** — body's first line starts with `#!`. The OS parses the shebang and invokes the interpreter.
- **Script recipes** — body is preceded by `[script]` or `[script(COMMAND)]`. `just` writes the body to a temp file and passes its path as an argument to `COMMAND`. No execute bit needed, no `cygpath` dance, no shebang-splitting inconsistency.

Both share the same temp-file plumbing (precedence rules below), but differ on portability, exec-bit requirements, and how interpreter args get split.

## Table of Contents

1. [Shebang recipes](#1-shebang-recipes)
   - [The polyglot example](#the-polyglot-example)
   - [Splitting interpreter args — `env -S`](#splitting-interpreter-args--env--s)
   - [Windows behavior — no native shebangs](#windows-behavior--no-native-shebangs)
   - [Safer Bash baseline — `set -euxo pipefail`](#safer-bash-baseline--set--euxo-pipefail)
   - [Windows path translation via `cygpath`](#windows-path-translation-via-cygpath)
2. [Script recipes — `[script]` and `[script(COMMAND)]`](#2-script-recipes--script-and-scriptcommand)
   - [What problems this avoids vs. shebang](#what-problems-this-avoids-vs-shebang)
   - [Empty `[script]` and `script-interpreter`](#empty-script-and-script-interpreter)
   - [Python with `uv` — both forms side-by-side](#python-with-uv--both-forms-side-by-side)
3. [Temp-file directory precedence](#3-temp-file-directory-precedence)
4. [See also](#4-see-also)

---

## 1. Shebang recipes

Source: <https://just.systems/man/en/shebang-recipes.html>

A recipe whose body's first line starts with `#!` is treated as a script — `just` writes the body to a temp file, marks it executable, and invokes it. The OS parses the shebang to determine the interpreter. For example, if a recipe starts with `#!/usr/bin/env bash`, the final command the OS runs is something like `/usr/bin/env bash /tmp/PATH_TO_SAVED_RECIPE_BODY`.

Because the OS executes the temp file directly, the filesystem holding it must allow execution — `noexec` mounts will fail. Script recipes (Section 2) avoid this requirement.

Shebang recipes are quiet by default (the body is not echoed before execution). Adding `@` to the recipe name flips that — `just` will print the body before running it.

### The polyglot example

```just
polyglot: python js perl sh ruby nu

python:
    #!/usr/bin/env python3
    print('Hello from python!')

js:
    #!/usr/bin/env node
    console.log('Greetings from JavaScript!')

perl:
    #!/usr/bin/env perl
    print "Larry Wall says Hi!\n";

sh:
    #!/usr/bin/env sh
    hello='Yo'
    echo "$hello from a shell script!"

nu:
    #!/usr/bin/env nu
    let hello = 'Hola'
    echo $"($hello) from a nushell script!"

ruby:
    #!/usr/bin/env ruby
    puts "Hello from ruby!"
```

```console
$ just polyglot
Hello from python!
Greetings from JavaScript!
Larry Wall says Hi!
Yo from a shell script!
Hola from a nushell script!
Hello from ruby!
```

### Splitting interpreter args — `env -S`

Shebang line splitting is operating-system dependent. When passing a command with arguments through `/usr/bin/env`, you may need to tell `env` to split them explicitly using `-S`:

```just
run:
    #!/usr/bin/env -S bash -x
    ls
```

Without `-S`, the kernel may pass `bash -x` as a single argument to `env` and fail to find an interpreter named `"bash -x"`. With `-S`, `env` splits the string itself, so multi-word shebangs work portably.

### Windows behavior — no native shebangs

Windows does not support shebang lines. On Windows, `just` splits the shebang line into a command and arguments, saves the recipe body to a file, and invokes the split command and arguments, adding the path to the saved body as the final argument. For example, on Windows, if a recipe starts with `#! py`, the final command the OS runs will be something like `py C:\Temp\PATH_TO_SAVED_RECIPE_BODY`.

### Safer Bash baseline — `set -euxo pipefail`

Source: <https://just.systems/man/en/safer-bash-shebang-recipes.html>

If you're writing a `bash` shebang recipe, consider adding `set -euxo pipefail`:

```just
foo:
    #!/usr/bin/env bash
    set -euxo pipefail
    hello='Yo'
    echo "$hello from Bash!"
```

It isn't strictly necessary, but `set -euxo pipefail` turns on a few useful features that make `bash` shebang recipes behave more like normal, linewise `just` recipes:

| Flag | Effect |
|------|--------|
| `-e` | Exit on command failure |
| `-u` | Exit on undefined variable |
| `-x` | Print each line before executing |
| `-o pipefail` | Exit if any command in a pipeline fails (`bash`-specific, off in linewise recipes) |

Together these avoid a lot of shell-scripting gotchas. For non-bash interpreters, find the equivalent strict-mode flags (e.g. `set -eu` for plain `sh`, `set -e` plus explicit `pipefail` checks where supported).

### Windows path translation via `cygpath`

On Windows, shebang interpreter paths containing a `/` are translated from Unix-style paths to Windows-style paths using `cygpath`, a utility that ships with [Cygwin](http://www.cygwin.com/).

For example, to execute this recipe on Windows:

```just
echo:
    #!/bin/sh
    echo "Hello!"
```

The interpreter path `/bin/sh` will be translated to a Windows-style path using `cygpath` before being executed.

If the interpreter path does not contain a `/`, it will be executed without being translated. This is useful if `cygpath` is not available, or you wish to pass a Windows-style path to the interpreter.

---

## 2. Script recipes — `[script]` and `[script(COMMAND)]`

Source: <https://just.systems/man/en/script-recipes.html>

Two attribute forms (full syntax in [`attributes.md#script--scriptcommand`](attributes.md#script--scriptcommand)):

- `[script(COMMAND)]` (1.32.0+) — body is evaluated, written to disk, and `COMMAND` is invoked with the temp-file path as its final argument.
- `[script]` (1.33.0+) — same, but `COMMAND` defaults to whatever `set script-interpreter` is (default `['sh', '-eu']`).

The body of the recipe is evaluated, written to disk in the temporary directory, and run by passing its path as an argument to `COMMAND`.

### What problems this avoids vs. shebang

Recipes with `[script(COMMAND)]` avoid four issues that shebang recipes have on at least one platform:

1. The use of `cygpath` on Windows.
2. The need to use `/usr/bin/env` for portable interpreter resolution.
3. Inconsistencies in shebang-line splitting across Unix OSs.
4. Requiring a temporary directory from which files can be executed (i.e. not mounted `noexec`). Script recipes pass the path to a command, so the temp file does not need execute permission.

If your interpreter requires a specific filename suffix (e.g. some tools dispatch on `.py`/`.ts`), use `[extension('.py')]` alongside `[script]` — see [`attributes.md#extensionext`](attributes.md#extensionext).

### Empty `[script]` and `script-interpreter`

Recipes with an empty `[script]` attribute are executed with the value of `set script-interpreter := […]` (1.33.0+), defaulting to `['sh', '-eu']`, and **not** the value of `set shell`. Full setting prose lives in [`settings.md#set-script-interpreter-1330`](settings.md#set-script-interpreter-1330); the related shell setting (which `[script]` ignores) is at [`settings.md#set-shell`](settings.md#set-shell).

This split is intentional: `set shell` configures how *linewise* recipes and backticks run, while `set script-interpreter` configures how *script-attribute* recipes run. Changing one doesn't affect the other.

### Python with `uv` — both forms side-by-side

Source: <https://just.systems/man/en/python-recipes-with-uv.html>

[`uv`](https://github.com/astral-sh/uv) is an excellent cross-platform Python project manager, written in Rust. Using the `[script]` attribute and `script-interpreter` setting, `just` can easily be configured to run Python recipes with `uv`:

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

The `# /// script ... # ///` block is [PEP 723 inline metadata](https://peps.python.org/pep-0723/) — `uv run --script` reads it to provision a per-script interpreter and dependency set on the fly. No virtualenv to manage, no `requirements.txt` checked in.

Of course, a shebang also works:

```just
hello:
  #!/usr/bin/env -S uv run --script
  print("Hello from Python!")
```

The shebang form is fine for one-off recipes; the `[script]` form scales better when most recipes in a justfile share an interpreter (set it once with `set script-interpreter`, drop the shebang from every body).

---

## 3. Temp-file directory precedence

Source: <https://just.systems/man/en/script-and-shebang-recipe-temporary-files.html>

Both shebang and script recipes write the recipe body to a temporary file. Shebang recipes execute that file directly — execution will fail if the filesystem containing the temp file is mounted with `noexec` or is otherwise non-executable. Script recipes pass the path to an interpreter, so the temp file does not need to be executable.

The directory `just` writes temp files to is configured, from highest to lowest precedence:

1. Globally with the `--tempdir` command-line option or the `JUST_TEMPDIR` environment variable (1.41.0+).
2. On a per-module basis with the `tempdir` setting (`set tempdir := 'PATH'`) — see [`settings.md#set-tempdir`](settings.md#set-tempdir).
3. Globally on Linux with the `XDG_RUNTIME_DIR` environment variable.
4. Falling back to the directory returned by [`std::env::temp_dir`](https://doc.rust-lang.org/std/env/fn.temp_dir.html).

The Linux-only `XDG_RUNTIME_DIR` rung exists because that directory is typically a `tmpfs` owned by the current user with `exec` permission — exactly what shebang recipes need. If you're on a system where the default temp dir is `noexec`, point `--tempdir` / `JUST_TEMPDIR` / `set tempdir` at an exec-able location, or migrate the recipe from shebang to `[script]`.

---

## 4. See also

- [`attributes.md#script--scriptcommand`](attributes.md#script--scriptcommand) — full attribute syntax for `[script]` / `[script(COMMAND)]`.
- [`attributes.md#extensionext`](attributes.md#extensionext) — `[extension('.ext')]`, useful when the interpreter dispatches on filename suffix.
- [`settings.md#set-script-interpreter-1330`](settings.md#set-script-interpreter-1330) — where the default `['sh', '-eu']` lives, plus how to override it.
- [`settings.md#set-tempdir`](settings.md#set-tempdir) — per-module temp-dir override (precedence rung 2).
- [`settings.md#set-shell`](settings.md#set-shell) — the shell setting that `[script]` recipes deliberately *ignore*.
- `recipes.md` — recipe params, deps, sigils, naming, indentation.
- `expressions.md` — `{{interpolation}}`, conditionals, positional-args mode.
- `errors.md` — `[no-exit-message]`, `error()`, `assert()`.
