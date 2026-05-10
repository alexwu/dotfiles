# Justfile Modules and Imports — Reference

Two mechanisms for splitting a justfile across multiple files:

- **`mod`** — load another file as a *namespaced submodule*. Recipes are addressed under the module's name. Each module is its own world (own settings, own variables, own cwd).
- **`import`** — *inline* the contents of another file into the current module. Recipes/variables/settings merge in as if written here.

Pick `mod` when you want isolation and namespacing (think: subcommands like `just docker::build`). Pick `import` when you want to share recipes/variables across files in one flat namespace.

## Table of Contents

1. [Modules — `mod`](#modules--mod)
   - [`mod foo` — search order](#mod-foo--search-order)
   - [Addressing module recipes](#addressing-module-recipes)
   - [`mod foo 'PATH'` — explicit path](#mod-foo-path--explicit-path)
   - [`mod? foo` — optional modules](#mod-foo--optional-modules)
   - [Module doc comments](#module-doc-comments)
   - [Module semantics — what crosses the boundary](#module-semantics--what-crosses-the-boundary)
2. [Imports — `import`](#imports--import)
   - [`import 'PATH'` — basic](#import-path--basic)
   - [Path resolution](#path-resolution)
   - [`import?` — optional imports](#import--optional-imports)
   - [Override semantics](#override-semantics)
   - [Repeated imports (1.37.0+)](#repeated-imports-1370)
3. [`mod` vs `import` — quick decision table](#mod-vs-import--quick-decision-table)
4. [See also](#see-also)

---

## Modules — `mod`

Source: <https://just.systems/man/en/modules.html>

`mod foo` — load a submodule. Stabilized in 1.31.0 (introduced 1.19.0).

### `mod foo` — search order

`just` searches, in order:

1. `foo.just`
2. `foo/mod.just`
3. `foo/justfile`
4. `foo/.justfile`

For the latter two (`foo/justfile`, `foo/.justfile`), the filename may have **any capitalization**.

```just
mod bar

a:
    @echo A
```

`bar.just`:

```just
b:
    @echo B
```

### Addressing module recipes

```console
$ just bar b
B
$ just bar::b
B
```

Both `space` and `::` path syntax work. Listing details (e.g. `just --list bar` or `just --list bar::b`) live in `recipes.md`.

### `mod foo 'PATH'` — explicit path

Explicit source. Leading `~/` expands to the home directory. `PATH` may be:

- A file (the module source file directly), or
- A directory containing one of: `mod.just`, `justfile`, `.justfile` (the latter two with any capitalization).

```just
mod foo 'PATH'
```

### `mod? foo` — optional modules

Missing source files don't error. Multiple `mod?` statements with the same name and **different paths** can coexist as long as at most one of them resolves.

```just
mod? foo 'bar.just'
mod? foo 'baz.just'
```

Useful for OS-conditional modules, optional plugins, or per-host overrides.

### Module doc comments

A `#` comment immediately above a `mod` statement becomes the module's doc comment in `--list` output (1.30.0+):

```just
# foo is a great module!
mod foo
```

```console
$ just --list
Available recipes:
    foo ... # foo is a great module!
```

The `...` indicates a submodule rather than a recipe. For attribute-based docs and groups (which work on recipes — and the same group/doc machinery applies to module-level decoration), see [`attributes.md#doc--docdoc`](attributes.md#doc--docdoc) and [`attributes.md#groupname`](attributes.md#groupname).

### Module semantics — what crosses the boundary

The boundary between a parent and a submodule is **strict**:

- **Recipes / aliases / variables** in one submodule are **not** visible in another, and not visible from the parent. There is currently no syntax to refer to another module's variables (tracked upstream).
- **Settings** are per-module — `set X` in the parent does **not** propagate into submodules. Each module sets what it needs. Full settings table in [`settings.md`](settings.md).
- **Working directory:** submodule recipes (without `[no-cd]`) run with cwd set to the directory containing the submodule source file. Recipes opt out via `[no-cd]` (see `attributes.md`).
- **`justfile()` and `justfile_directory()`** always return the **root** justfile's path/dir, even when called from a submodule recipe. Use `module_file()` / `module_directory()` for the current submodule.
- **Environment files** load **per module**, respecting that module's own `dotenv-*` settings. Env vars from parent modules ARE visible in children.

Listing recipes inside a module (`just --list foo`, `just --list foo::bar`) is described in [`recipes.md`](recipes.md).

---

## Imports — `import`

Source: <https://just.systems/man/en/imports.html>

```just
import 'foo/bar.just'

a: b
    @echo A
```

`foo/bar.just`:

```just
b:
    @echo B
```

### `import 'PATH'` — basic

```console
$ just b
B
$ just a
B
A
```

Imports **inline** the contents — recipes, variables, and settings from the imported file are merged into the current module. There is no namespacing; `b` from `foo/bar.just` becomes a top-level recipe of the importing file.

### Path resolution

- Path may be **absolute** or **relative to the importing file**.
- Leading `~/` expands to the user's home directory.
- Imports are processed **recursively** — imported files can themselves `import` more files.
- Justfiles are **insensitive to declaration order**. An imported file can reference variables/recipes defined after the `import` statement (or in a sibling import).

### `import?` — optional imports

```just
import? 'foo/bar.just'
```

No error if the file is missing. Useful for optional local overrides (e.g. `import? 'justfile.local'`).

### Override semantics

`set allow-duplicate-recipes` and `set allow-duplicate-variables` enable later definitions to override earlier ones in the same module:

```just
set allow-duplicate-recipes

foo:

foo:
    echo 'yes'
```

When `import`s are involved, the rules expand:

- **Shallower overrides deeper.** Recipes at the top level override recipes in imports; recipes in an import override recipes in an import that *itself* imports those recipes.
- **Same-depth tiebreak: earlier wins.** When two duplicate definitions are imported at the same depth, the one from the **earlier** `import` overrides the one from the later `import`. (Upstream notes this is technically a bug — the import stack processes in reverse — but is preserved for backwards compatibility. See upstream issue #2540.)

### Repeated imports (1.37.0+)

Importing the same source file multiple times is **not an error** as of 1.37.0. This lets two siblings each import a shared file without conflict:

```just
# justfile
import 'foo.just'
import 'bar.just'
```

```just
# foo.just
import 'baz.just'
foo: baz
```

```just
# bar.just
import 'baz.just'
bar: baz
```

```just
# baz.just
baz:
```

`baz` is defined once, transitively imported twice — no error.

---

## `mod` vs `import` — quick decision table

| Need                                                              | Use      |
|-------------------------------------------------------------------|----------|
| Subcommand-style namespacing (`just docker::build`)               | `mod`    |
| Per-area settings, env files, working directory                   | `mod`    |
| Recipes share the same name across areas without colliding        | `mod`    |
| Pull in a shared library of recipes/variables into one flat space | `import` |
| Local override file (`justfile.local`)                            | `import?`|
| Multiple files referring to each other's variables                | `import` |
| Optional / conditional inclusion                                  | `mod?` or `import?` |

---

## See also

- [`attributes.md#doc--docdoc`](attributes.md#doc--docdoc) — `[doc("...")]` attribute on recipes (module doc comments use the bare `# comment` form above `mod`).
- [`attributes.md#groupname`](attributes.md#groupname) — `[group('name')]` for recipe grouping in `--list` output.
- [`settings.md`](settings.md) — full settings table; remember each module owns its own settings, none propagate.
- [`recipes.md`](recipes.md) — recipe listing and addressing details (`just --list foo`, `just --list foo::bar`, `just foo bar` vs `just foo::bar`).
