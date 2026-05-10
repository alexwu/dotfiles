# Justfile Built-in Functions — Full Reference

71 built-in functions, usable in expressions, recipe-body `{{…}}` substitutions, assignments, and default parameter values. All return strings. Source: <https://just.systems/man/en/built-in-functions.html>.

Functions ending in `_directory` may be abbreviated to `_dir`. `home_directory()` ↔ `home_dir()`. `invocation_directory_native()` ↔ `invocation_dir_native()`.

Many path/file functions and `env(key)` (single-arg form) **abort recipe execution** if they fail. Each entry below flags fallibility.

## Table of Contents

- [System Information](#system-information) — `arch`, `num_cpus`, `os`, `os_family`
- [External Commands](#external-commands) — `shell`
- [Environment Variables](#environment-variables) — `env`, `env_var`, `env_var_or_default`
- [Executables](#executables) — `require`, `which`
- [Invocation & Process Information](#invocation--process-information) — `is_dependency`, `invocation_directory`, `invocation_directory_native`, `justfile`, `justfile_directory`, `source_file`, `source_directory`, `module_file`, `module_directory`, `module_path`, `just_executable`, `just_pid`
- [String Manipulation](#string-manipulation) — `append`, `prepend`, `encode_uri_component`, `quote`, `replace`, `replace_regex`, `trim`/`trim_*`
- [Case Conversion](#case-conversion) — `capitalize`, `kebabcase`, `lowercamelcase`, `lowercase`, `shoutykebabcase`, `shoutysnakecase`, `snakecase`, `titlecase`, `uppercamelcase`, `uppercase`
- [Path Manipulation (Fallible)](#path-manipulation-fallible) — `absolute_path`, `canonicalize`, `extension`, `file_name`, `file_stem`, `parent_directory`, `without_extension`
- [Path Manipulation (Infallible)](#path-manipulation-infallible) — `clean`, `join`
- [Filesystem Access](#filesystem-access) — `path_exists`, `read`
- [Error Reporting](#error-reporting) — `assert`, `error`
- [Hashing](#hashing) — `blake3`, `blake3_file`, `sha256`, `sha256_file`, `uuid`
- [Random](#random) — `choose`
- [Datetime](#datetime) — `datetime`, `datetime_utc`
- [Semantic Versions](#semantic-versions) — `semver_matches`
- [Style](#style) — `style`
- [User Directories](#user-directories--xdg) — `cache_directory`, `config_directory`, `config_local_directory`, `data_directory`, `data_local_directory`, `executable_directory`, `home_directory`, `runtime_directory`

## System Information

| Function | Since | Returns |
|----------|------:|---------|
| `arch()` | — | Instruction-set architecture: `"aarch64"`, `"arm"`, `"asmjs"`, `"hexagon"`, `"mips"`, `"msp430"`, `"powerpc"`, `"powerpc64"`, `"s390x"`, `"sparc"`, `"wasm32"`, `"x86"`, `"x86_64"`, `"xcore"` |
| `num_cpus()` | 1.15.0 | Number of logical CPUs as a decimal string |
| `os()` | — | OS: `"android"`, `"bitrig"`, `"dragonfly"`, `"emscripten"`, `"freebsd"`, `"haiku"`, `"ios"`, `"linux"`, `"macos"`, `"netbsd"`, `"openbsd"`, `"solaris"`, `"windows"` |
| `os_family()` | — | `"unix"` or `"windows"` |

```just
system-info:
    @echo "This is an {{arch()}} machine."
```

```console
$ just system-info
This is an x86_64 machine.
```

For cross-platform recipes branching on OS, see [`examples/cross-platform.just`](https://github.com/casey/just/blob/master/examples/cross-platform.just) — or just use `[unix]`/`[windows]` attributes (see attributes reference).

## External Commands

### `shell(command, args…)` (1.27.0)

Returns stdout of `command`, executed by the shell that runs recipe lines (default `sh -cu`, override with `set shell`). `command` is passed as the first argument to the shell, *and* as `$0`. Subsequent `args` become `$1`, `$2`, … and are visible via `$@`.

With the default shell `sh -cu` and `args` `'foo'`, `'bar'`, the shell receives:

```
'sh' '-cu' 'echo $@' 'echo $@' 'foo' 'bar'
```

— so `$@` works as expected (excluding `$0`).

```just
# Arguments can be variables or expressions.
file := '/sys/class/power_supply/BAT0/status'
bat0stat := shell('cat $1', file)

# Commands can be variables or expressions.
command := 'wc -l'
output := shell(command + ' "$1"', 'main.c')

# Arguments referenced by the shell command must be used.
empty := shell('echo', 'foo')           # echoes nothing — `foo` is unreferenced
full  := shell('echo $1', 'foo')        # echoes "foo"
```

```just
# Using Python as the shell. `python -c` sets sys.argv[0] to '-c',
# so the first "real" positional argument is sys.argv[2].
set shell := ["python3", "-c"]
olleh := shell('import sys; print(sys.argv[2][::-1])', 'hello')
```

## Environment Variables

### `env(key)` (1.15.0) — fallible

Retrieves env var `key`, **aborting if not present**.

```just
home_dir := env('HOME')

test:
    echo "{{home_dir}}"
```

### `env(key, default)` (1.15.0)

Retrieves env var `key`, returning `default` (a string) if not present. Note that an *empty* env var still returns `""`, not `default`.

To use `default` when the var is unset *or* empty, use the `||` operator (unstable):

```just
set unstable
foo := env('FOO', '') || 'DEFAULT_VALUE'
```

### `env_var(key)` and `env_var_or_default(key, default)`

Deprecated aliases for `env(key)` and `env(key, default)`. Prefer the new spellings in new code.

## Executables

### `require(name)` (1.39.0) — fallible

Search `PATH` for executable `name`, return its full path, or **abort the recipe** if no executable found.

```just
bash := require("bash")

@test:
    echo "bash: '{{bash}}'"
```

```console
$ just
bash: '/bin/bash'
```

Use this at module scope to fail fast when a tool is missing.

### `which(name)` (1.39.0, unstable)

Search `PATH` for executable `name`, return its full path, or the **empty string** if no executable found. Requires `set unstable`.

```just
set unstable

bosh := which("bosh")

@test:
    echo "bosh: '{{bosh}}'"
```

Use this for optional tools — branch on `which("foo") != ""`.

## Invocation & Process Information

| Function | Returns |
|----------|---------|
| `is_dependency()` | `"true"` if the current recipe is running as a dep of another, else `"false"` |
| `invocation_directory()` | Absolute path to the user's cwd at the moment `just` was invoked. On Windows, uses `cygpath` for `/`-separator output |
| `invocation_directory_native()` | Same, but verbatim native form (no cygpath) |
| `justfile()` | Path of the current root justfile |
| `justfile_directory()` | Parent directory of the root justfile |
| `source_file()` (1.27.0) | Path of the current source file (root justfile, or imported/submodule file) |
| `source_directory()` (1.27.0) | Parent directory of `source_file()` |
| `module_file()` | Path of the current module file |
| `module_directory()` | Parent directory of `module_file()` |
| `module_path()` | `::`-separated module path of the current module |
| `just_executable()` | Absolute path to the `just` binary itself |
| `just_pid()` | PID of the running `just` process |

```just
rustfmt:
    find {{invocation_directory()}} -name \*.rs -exec rustfmt {} \;

build:
    cd {{invocation_directory()}}; ./some_script_that_needs_to_be_run_from_here

script:
    {{justfile_directory()}}/scripts/some_script

executable:
    @echo The executable is at: {{just_executable()}}
```

`source_file()` and `source_directory()` behave like `justfile()`/`justfile_directory()` in the root justfile, but return the path of the current `import` source file or submodule file when called from inside one. Same pattern for `module_file()` / `module_directory()` (specifically for `mod` submodules, not `import`).

## String Manipulation

| Function | Behavior |
|----------|----------|
| `append(suffix, s)` (1.27.0) | Append `suffix` to each whitespace-separated word in `s` |
| `prepend(prefix, s)` (1.27.0) | Prepend `prefix` to each word in `s` |
| `encode_uri_component(s)` (1.27.0) | Percent-encode chars in `s` except `[A-Za-z0-9_.!~*'()-]` (matches JS `encodeURIComponent`) |
| `quote(s)` | Replace `'` with `'\''` and wrap in single quotes — shell-safe quoting |
| `replace(s, from, to)` | Replace all literal occurrences of `from` with `to` |
| `replace_regex(s, regex, replacement)` | Replace via Rust [`regex` crate](https://docs.rs/regex/latest/regex/). Capture groups via [replacement string syntax](https://docs.rs/regex/latest/regex/struct.Regex.html#replacement-string-syntax) |
| `trim(s)` | Strip leading + trailing whitespace |
| `trim_start(s)` / `trim_end(s)` | Strip leading-only / trailing-only whitespace |
| `trim_start_match(s, sub)` / `trim_end_match(s, sub)` | Strip ONE matching prefix/suffix |
| `trim_start_matches(s, sub)` / `trim_end_matches(s, sub)` | Repeatedly strip matching prefixes/suffixes |

Examples:

```just
# `'foo/src bar/src baz/src'`
files := append('/src', 'foo bar baz')

# `'src/foo src/bar src/baz'`
sources := prepend('src/', 'foo bar baz')

# Shell-safe quoting — non-negotiable for any user-supplied param interpolated into bash.
echo {{quote(prompt)}}
```

## Case Conversion

| Function | Since | Result |
|----------|------:|--------|
| `capitalize(s)` | 1.7.0 | First char uppercase, rest lowercase |
| `kebabcase(s)` | 1.7.0 | `kebab-case` |
| `lowercamelcase(s)` | 1.7.0 | `lowerCamelCase` |
| `lowercase(s)` | — | All lowercase |
| `shoutykebabcase(s)` | 1.7.0 | `SHOUTY-KEBAB-CASE` |
| `shoutysnakecase(s)` | 1.7.0 | `SHOUTY_SNAKE_CASE` |
| `snakecase(s)` | 1.7.0 | `snake_case` |
| `titlecase(s)` | 1.7.0 | `Title Case` |
| `uppercamelcase(s)` | 1.7.0 | `UpperCamelCase` |
| `uppercase(s)` | — | All uppercase |

## Path Manipulation (Fallible)

These can fail (e.g. on a path without an extension) and **abort the recipe**.

| Function | Behavior |
|----------|----------|
| `absolute_path(path)` | Absolute path to relative `path` from cwd. `absolute_path("./bar.txt")` in `/foo` → `"/foo/bar.txt"` |
| `canonicalize(path)` (1.24.0) | Resolve symlinks, remove `.`/`..`/extra `/` |
| `extension(path)` | Extension. `extension("/foo/bar.txt")` → `"txt"` |
| `file_name(path)` | Basename. `file_name("/foo/bar.txt")` → `"bar.txt"` |
| `file_stem(path)` | Basename without extension. `file_stem("/foo/bar.txt")` → `"bar"` |
| `parent_directory(path)` | Dirname. `parent_directory("/foo/bar.txt")` → `"/foo"` |
| `without_extension(path)` | Path with extension removed. `without_extension("/foo/bar.txt")` → `"/foo/bar"` |

## Path Manipulation (Infallible)

### `clean(path)`

Simplify path: remove redundant separators, intermediate `.`, and resolve `..` where possible.

```
clean("foo//bar")    → "foo/bar"
clean("foo/..")      → "."
clean("foo/./bar")   → "foo/bar"
```

### `join(a, b…)`

Join path components. **On Windows uses `\`, on Unix uses `/`.** This can lead to unwanted behavior — prefer the `/` operator (`a / b`) which always uses `/`. `join` accepts two or more args.

```just
out := join("foo/bar", "baz")     # "foo/bar/baz"
out := "foo/bar" / "baz"          # "foo/bar/baz" — preferred for cross-platform
```

## Filesystem Access

### `path_exists(path)`

Returns the string `"true"` if the path points at an existing entity, `"false"` otherwise. Traverses symlinks. Returns `"false"` for inaccessible paths or broken symlinks.

```just
foo := if path_exists("/etc/passwd") == "true" { "yes" } else { "no" }
```

### `read(path)` (1.39.0)

Returns the content of file at `path` as a string. Useful for reading version files, config snippets, etc.

```just
version := trim(read("VERSION"))
```

## Error Reporting

### `assert(CONDITION, EXPRESSION)` (1.27.0)

Error with message `EXPRESSION` if `CONDITION` evaluates to false (any non-empty string truthy condition).

### `error(message)`

Abort execution and report `message` as an error. Often paired with `if`/`else` chains:

```just
foo := if "hello" == "goodbye" {
    "xyz"
} else if "a" == "b" {
    "abc"
} else {
    error("123")
}
```

See also: [Stopping execution with error](https://just.systems/man/en/stopping-execution-with-error.html).

## Hashing

| Function | Since | Returns |
|----------|------:|---------|
| `blake3(string)` | 1.25.0 | BLAKE3 hash of `string` as hex string |
| `blake3_file(path)` | 1.25.0 | BLAKE3 hash of file at `path` as hex string |
| `sha256(string)` | — | SHA-256 hash of `string` as hex string |
| `sha256_file(path)` | — | SHA-256 hash of file at `path` as hex string |
| `uuid()` | — | Random version-4 UUID |

## Random

### `choose(n, alphabet)` (1.27.0)

Generate a string of `n` randomly selected characters from `alphabet`. `alphabet` may not contain repeated characters.

```just
token := choose("64", HEX)        # 64-char lowercase hex
slug  := choose("8",  HEXUPPER)
```

## Datetime

### `datetime(format)` (1.30.0)

Return local time formatted via `strftime`-style format string.

### `datetime_utc(format)` (1.30.0)

Same, in UTC.

```just
build_date := datetime_utc("%Y-%m-%dT%H:%M:%SZ")
filename   := "build-" + datetime("%Y%m%d-%H%M%S") + ".tar.gz"
```

Format string reference: [`chrono` strftime docs](https://docs.rs/chrono/latest/chrono/format/strftime/index.html).

## Semantic Versions

### `semver_matches(version, requirement)` (1.16.0)

Check whether a [semantic version](https://semver.org/) matches a requirement string. Returns `"true"` or `"false"`.

```just
ok := semver_matches("0.1.5", ">=0.1.0")     # "true"
```

## Style

### `style(name)` (1.37.0)

Return the ANSI escape sequence `just` itself uses for a named style. `name` is one of `'command'`, `'error'`, `'warning'`. Use this to make recipe output match `just`'s own coloring.

```just
scary:
    @echo '{{ style("error") }}OH NO{{ NORMAL }}'
```

For arbitrary colors, use the constants table (`RED`, `GREEN`, `BG_BLUE`, `BOLD`, etc. — see `recipe-syntax.md`).

## User Directories — XDG

Returns paths to user-specific directories. On Unix, follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html). On macOS and Windows, returns the OS-specified equivalents (e.g. `cache_directory()` → `~/Library/Caches` on macOS, `{FOLDERID_LocalAppData}` on Windows). See the [`dirs` crate](https://docs.rs/dirs/latest/dirs/index.html) for details.

| Function | Returns |
|----------|---------|
| `cache_directory()` | User-specific cache dir |
| `config_directory()` | User-specific config dir |
| `config_local_directory()` | Local user-specific config dir |
| `data_directory()` | User-specific data dir |
| `data_local_directory()` | Local user-specific data dir |
| `executable_directory()` | User-specific executable dir |
| `home_directory()` | User's home dir |
| `runtime_directory()` | User-specific runtime dir (Linux only) |

If you want strict XDG semantics on every platform, do it explicitly with `env(...)` and `home_directory()`:

```just
xdg_config_dir := if env('XDG_CONFIG_HOME', '') =~ '^/' {
    env('XDG_CONFIG_HOME')
} else {
    home_directory() / '.config'
}
```

(The XDG spec says non-absolute `$XDG_CONFIG_HOME` values must be ignored.)
