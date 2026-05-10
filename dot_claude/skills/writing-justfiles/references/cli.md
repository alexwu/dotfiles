# Justfile CLI — Reference

The flags angle on `just`. Everything you'd find on `just --help` or in the
man-page-adjacent chapters: how the binary is driven from the shell, how to
pick a different justfile, how to override variables, how to introspect
without running, how signals are handled, and which env vars mirror common
flags.

For UX-driven coverage of `--list` / `--summary` / `--groups` — what the
output looks like, how groups and `[group(...)]` interact, hidden recipes —
see [recipes.md](recipes.md). For the canonical settings table (every
`set foo := …` and how CLI flags override them), see
[settings.md](settings.md). For what `--evaluate` is actually printing, see
[expressions.md](expressions.md).

## Table of Contents

- [Flags quick reference](#flags-quick-reference)
- [Environment-variable alternatives](#environment-variable-alternatives)
- [Picking a justfile: `--justfile`, `-g`, `--working-directory`](#picking-a-justfile---justfile--g---working-directory)
- [Global / user justfiles](#global--user-justfiles)
- [Setting variables from the command line](#setting-variables-from-the-command-line)
- [Introspection: `--evaluate`, `--evaluate-format`, `--show`, `--usage`](#introspection---evaluate---evaluate-format---show---usage)
- [`--dump` and `--fmt`](#--dump-and---fmt)
- [Listing flags: `--list-heading`, `--list-prefix`, `--man`, `--completions`](#listing-flags---list-heading---list-prefix---man---completions)
- [Shell, tempdir, dotenv, timestamps](#shell-tempdir-dotenv-timestamps)
- [`--unstable`, `--yes`, `--one`](#--unstable---yes---one)
- [Signal handling](#signal-handling)

---

## Flags quick reference

Source: <https://just.systems/man/en/command-line-options.html>

```console
$ just --list
$ just --summary
$ just --groups
$ just --show RECIPE
$ just --evaluate [VAR]
$ just --evaluate-format <just|shell>
$ just --usage RECIPE
$ just --set NAME VALUE
$ just NAME=VALUE recipe ...
$ just --justfile PATH
$ just --working-directory DIR
$ just --shell SHELL --shell-arg ARG
$ just --tempdir DIR
$ just --dotenv-path PATH         # alias: -E PATH
$ just --timestamp [--timestamp-format FMT]
$ just --yes                      # auto-confirm
$ just --unstable                 # also: JUST_UNSTABLE=1
$ just --global-justfile          # short: -g
$ just --one
$ just --man
$ just --dump [--dump-format json]
$ just --list-heading TEXT --list-prefix TEXT
$ just --fmt [--check]
$ just --completions <shell>
```

`just --help` lists the full set, including which flags can be set with env
vars. For a worked example of using `--list`/`--summary`/`--groups` to drive
listing UX (group ordering, hidden recipes, the default `default`-recipe
trick), see [recipes.md](recipes.md).

---

## Environment-variable alternatives

Source: <https://just.systems/man/en/command-line-options.html>

Some command-line options can be set with environment variables. For
example, unstable features can be enabled either with the `--unstable`
flag:

```console
$ just --unstable
```

Or by setting the `JUST_UNSTABLE` environment variable:

```console
$ export JUST_UNSTABLE=1
$ just
```

The practical difference: env vars are inherited by child processes, so
nested `just` invocations pick them up automatically; flags passed on the
command line do **not** propagate to recursive invocations of `just`.

Common env-var aliases:

- `JUST_UNSTABLE` ↔ `--unstable` — see
  [settings.md#set-unstable-1310](settings.md#set-unstable-1310) for the equivalent `set unstable`
  setting in the justfile itself.
- `JUST_TEMPDIR` ↔ `--tempdir` (1.41.0+) — see
  [settings.md#set-tempdir](settings.md#set-tempdir). Note that for shebang/script-recipe
  temp files there's a precedence order documented in
  [scripts.md](scripts.md).

`just --help` is the source of truth for which other flags have env-var
counterparts.

---

## Picking a justfile: `--justfile`, `-g`, `--working-directory`

By default `just` walks up from the cwd looking for a `justfile`
(case-insensitive match — `justfile` / `Justfile` / `JUSTFILE` / `JuStFiLe`
/ `.justfile`).

- `--justfile PATH` — point at a specific file. Combine with
  `--working-directory DIR` so recipes resolve relative paths the way you
  want.
- `--working-directory DIR` — sets cwd before running recipes; without
  `--justfile` it disables the upward search.
- `-g` / `--global-justfile` — use the global/user justfile (next section)
  without naming a path.

---

## Global / user justfiles

Source: <https://just.systems/man/en/global-and-user-justfiles.html>

`just --global-justfile`, or `just -g` for short, searches the following
paths, in-order, for a justfile:

- `$XDG_CONFIG_HOME/just/justfile`
- `$HOME/.config/just/justfile`
- `$HOME/justfile`
- `$HOME/.justfile`

First hit wins. Put recipes that are useful across many projects there and
invoke them from any directory with `just -g RECIPE`.

### Single-alias variant

Create a single alias to invoke recipes from the user justfile:

```console
alias .j='just --justfile ~/.user.justfile --working-directory .'
```

Now `.j foo` runs the `foo` recipe from `~/.user.justfile`. Or alias every
recipe via a `for recipe in $(just --justfile … --summary)` loop — see
<https://just.systems/man/en/global-and-user-justfiles.html>.

---

## Setting variables from the command line

Source: <https://just.systems/man/en/setting-variables-from-the-command-line.html>

Variables defined with `:=` can be overridden from the command line. Any
number of `NAME=VALUE` arguments can be passed before recipes, or use the
`--set` flag:

```console
$ just os=plan9 build
./build plan9
$ just --set os bsd build
./build bsd
```

Variables in submodules can be overridden using the `::`-separated path to
the variable. A variable named `bar` in a submodule named `foo` may be
overridden with `foo::bar=VALUE` or `--set foo::bar VALUE`.

For the assignment semantics these overrides interact with (lazy/eager,
backticks, `export`), see [expressions.md](expressions.md).

---

## Introspection: `--evaluate`, `--evaluate-format`, `--show`, `--usage`

Print computed assignments without running anything:

```console
$ just --evaluate
bar := "world"
foo := "hello"
$ just --evaluate foo
hello
```

Submodule paths (`bob::bar`, `bob::bar::y`) work too (1.49.0+).

`--evaluate-format` (1.49.0+) picks the printed form (`just` or `shell`):

```console
$ just --evaluate --evaluate-format shell
bar="world"
foo="hello"
```

`shell` form is convenient for `eval "$(just --evaluate --evaluate-format
shell)"` style sourcing. For what counts as a variable (vs a constant vs an
exported env var), see [expressions.md](expressions.md).

`--show RECIPE` prints a recipe's source. `--usage RECIPE` prints just the
recipe's argument signature — handy for shell completion glue.

---

## `--dump` and `--fmt`

Source: <https://just.systems/man/en/formatting-and-dumping-justfiles.html>

Each `justfile` has a canonical formatting. `just --fmt` overwrites the
current justfile with the canonical version. Formatting is not covered by
any backwards compatibility guarantee — pin your `just` version in CI if
you care about format stability across releases.

`just --fmt --check` runs `--fmt` in check mode: exits 0 if formatted
correctly, exits 1 and prints a diff otherwise. This is the CI gate.

`just --dump` outputs a formatted justfile to stdout. With
`--dump-format json` it prints a JSON representation — useful for
`[metadata(...)]`-style tooling and external tools that consume justfile
structure without parsing the syntax themselves.

---

## Listing flags: `--list-heading`, `--list-prefix`, `--man`, `--completions`

Tweak the `--list` output without editing the justfile:

```console
$ just --list --list-heading $'Cool stuff…\n' --list-prefix ····
Cool stuff…
····test
····build
```

For the broader listing UX (groups, ordering, hidden recipes, `default`
recipe trick), see [recipes.md](recipes.md).

`just --man` prints the man page (roff). `just --completions <shell>`
prints a completion script for `bash`, `zsh`, `fish`, `powershell`,
`nushell`, etc. Source it from your shell init:

```console
$ just --completions bash > /etc/bash_completion.d/just
$ just --completions zsh  > ~/.zsh/completions/_just
```

---

## Shell, tempdir, dotenv, timestamps

`--shell SHELL` and `--shell-arg ARG` override the in-justfile
`set shell := [...]`. Passing either causes `just` to ignore any shell
settings in the current justfile — see
[settings.md#set-shell](settings.md#set-shell) for the precedence rules and the full
list of shell-related settings.

```console
$ just --shell powershell.exe --shell-arg -c
```

`--tempdir DIR` (or `JUST_TEMPDIR`, 1.41.0+) sets the temp directory
globally. For shebang/script recipes the temp-file directory is determined
by a precedence chain — see [scripts.md](scripts.md) for the full order;
the in-justfile equivalent is
[settings.md#set-tempdir](settings.md#set-tempdir).

`--dotenv-path PATH` (short: `-E PATH`) loads a specific `.env` file
instead of the default discovery. The dotenv settings in the justfile
itself live in [settings.md](settings.md).

`--timestamp` prefixes each command with the time it ran;
`--timestamp-format FMT` takes a chrono format string:

```console
$ just --timestamp recipe --timestamp-format '%H:%M:%S%.3f %Z'
[07:32:11:.349 UTC] echo one
one
[07:32:11:.350 UTC] sleep 2
[07:32:13:.352 UTC] echo two
two
```

---

## `--unstable`, `--yes`, `--one`

- `--unstable` (or `JUST_UNSTABLE=1`) enables unstable features. The
  in-justfile equivalent is `set unstable := true` — see
  [settings.md](settings.md).
- `--yes` auto-confirms recipes marked `[confirm("...")]`. Useful in CI
  where there's no TTY to prompt.
- `--one` requires that exactly one recipe be invoked per `just` call —
  the command line errors out if you pass zero or more than one. Defensive
  knob for scripts that build up a `just` invocation programmatically.

---

## Signal handling

Source: <https://just.systems/man/en/signal-handling.html>

`just` tries to exit when requested by a signal, but also tries to avoid
leaving behind running child processes — two goals somewhat in conflict.

- `SIGHUP` / `SIGINT` / `SIGQUIT` — sent to all processes in the
  foreground process group (terminal close, `ctrl-c`, `ctrl-\`).
- `SIGTERM` — default for `kill`; delivered only to its intended victim.
  On receipt, `just` forwards `SIGTERM` to running children (1.41.0+),
  since unlike other fatal signals it was likely sent to `just` alone.
- For all of the above: if no child is running, `just` exits immediately;
  if a child *is* running, `just` waits for it to terminate to avoid
  leaving it behind. Regardless of how the child exits, `just` halts
  execution after a fatal signal.
- `SIGINFO` — `ctrl-t` on BSD-derived OSes including macOS (not Linux).
  `just` prints a list of all child PIDs and commands (1.41.0+).
- On Windows, `just` behaves as if it had received `SIGINT` when the user
  types `ctrl-c`. Other signals are unsupported.
