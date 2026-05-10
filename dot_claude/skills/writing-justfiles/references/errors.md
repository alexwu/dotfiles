# Justfile Error Handling — Reference

Sources:
- <https://just.systems/man/en/quiet-recipes.html>
- <https://just.systems/man/en/stopping-execution-with-error.html>
- <https://just.systems/man/en/built-in-functions.html>

## Table of contents

1. [Default exit-message format](#default-exit-message-format)
2. [Suppress / force exit-message](#suppress--force-exit-message)
   - [`[no-exit-message]` per-recipe](#no-exit-message-per-recipe)
   - [`[exit-message]` per-recipe](#exit-message-per-recipe)
   - [`set no-exit-message` module-wide (1.39.0+)](#set-no-exit-message-module-wide-1390)
3. [`error(message)` — abort and report](#errormessage--abort-and-report)
4. [`assert(CONDITION, EXPRESSION)` (1.27.0+)](#assertcondition-expression-1270)
5. [When to reach for which](#when-to-reach-for-which)
6. [See also](#see-also)

---

## Default exit-message format

When a recipe's command exits non-zero, `just` prints the underlying tool's stderr followed by its own one-line summary identifying the failed recipe, line number, and exit code:

```console
$ just git status
fatal: not a git repository (or any of the parent directories): .git
error: Recipe `git` failed on line 2 with exit code 128
```

The shape is always `error: Recipe `<name>` failed on line <N> with exit code <Z>`. This second line is the "exit message" that the attributes below suppress or force.

Source: §16, `recipe-syntax.md`.

---

## Suppress / force exit-message

| Scope | Mechanism |
|-------|-----------|
| One recipe | `[no-exit-message]` (suppress), `[exit-message]` (force) |
| Module-wide | `set no-exit-message` (1.39.0+) — silence everywhere; `[exit-message]` still wins per-recipe |

Source: §16, `recipe-syntax.md`.

### `[no-exit-message]` per-recipe

Suppresses the trailing `error: Recipe ... failed ...` line for that single recipe. The underlying command's own stderr still prints. Use on wrapper recipes whose underlying tool already produces a perfectly good error message (e.g. `git`, `cargo`, `kubectl`) — the second line is just noise on top of a clear error the tool already wrote.

Source: §16, `recipe-syntax.md`.

Canonical attribute reference: [`attributes.md#no-exit-message`](attributes.md#no-exit-message).

### `[exit-message]` per-recipe

Forces the exit-message line to appear for that single recipe even when `set no-exit-message` is in effect module-wide. This is the per-recipe override on top of the module-wide silencer — useful when most recipes wrap chatty tools (silenced module-wide) but one specific recipe runs something terse where the `error: Recipe ...` summary is genuinely the most useful diagnostic.

Source: §16, `recipe-syntax.md`.

Canonical attribute reference: [`attributes.md#exit-message`](attributes.md#exit-message).

### `set no-exit-message` module-wide (1.39.0+)

`set no-exit-message := true` at the top of a justfile flips the default for every recipe in the module — no recipe prints the trailing summary unless it carries `[exit-message]`. Equivalent to stamping `[no-exit-message]` on every recipe, then opting individual recipes back in with `[exit-message]`.

Source: §16, `recipe-syntax.md` (settings table at line 448 lists `no-exit-message` (1.39.0+) bool, default `false`, "Module-wide `[no-exit-message]`").

Canonical setting reference: [`settings.md`](settings.md) — see the `no-exit-message` row in the settings table.

---

## `error(message)` — abort and report

Aborts evaluation and reports `message` to the user. Most commonly used inside an `if`/`else` chain over assignments to validate inputs or guard against unreachable branches at evaluation time (before any recipe runs).

The error fires during expression evaluation — *before* recipe bodies execute — so it's the right tool for "this configuration is invalid, don't even start." Compare against shell-side validation inside a recipe body, which only fires once that recipe runs.

Source: §16, `recipe-syntax.md`; mirrored in [Stopping execution with error](https://just.systems/man/en/stopping-execution-with-error.html).

See [`built-in-functions.md#error-reporting`](built-in-functions.md#error-reporting) for the signature and a worked if/else example.

---

## `assert(CONDITION, EXPRESSION)` (1.27.0+)

Errors with `EXPRESSION` if `CONDITION` is false (where false = empty string).

Source: §16, `recipe-syntax.md`.

Behaviorally this is sugar for `if CONDITION == "" { error(EXPRESSION) }` — `just` treats the empty string as false and any non-empty string as true, matching the convention used everywhere else in expression context (e.g. boolean settings, `if` guards). Reach for `assert` when you have a single precondition; reach for the `if`/`else`/`error` chain when the failure modes branch.

Canonical signature and full prose: [`built-in-functions.md`](built-in-functions.md) — Error Reporting section.

---

## When to reach for which

- **Wrapping a tool that prints its own clear error** (`git`, `cargo`, `kubectl`, `docker`, `npm`) → `[no-exit-message]` on that recipe. Don't double up on diagnostics.
- **Most of your justfile wraps chatty tools, with a few exceptions** → `set no-exit-message := true` at the top, then `[exit-message]` on the exceptions.
- **A configuration value is invalid and the rest of the justfile can't possibly make sense** → `error("...")` at assignment time. Fails fast, before any recipe body runs.
- **A single precondition over an expression** (env var present, version matches, file exists) → `assert(CONDITION, "...")`. One line, one purpose.

---

## See also

- [`attributes.md#no-exit-message`](attributes.md#no-exit-message) — canonical attribute reference for `[no-exit-message]`.
- [`attributes.md#exit-message`](attributes.md#exit-message) — canonical attribute reference for `[exit-message]`.
- [`built-in-functions.md`](built-in-functions.md) — canonical signatures and full prose for `error()` and `assert()` (Error Reporting section).
- [`settings.md`](settings.md) — canonical reference for `set no-exit-message` (1.39.0+).
- Upstream: <https://just.systems/man/en/stopping-execution-with-error.html>, <https://just.systems/man/en/quiet-recipes.html>.
