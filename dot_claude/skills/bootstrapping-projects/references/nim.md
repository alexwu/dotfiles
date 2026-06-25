# Nim project bootstrap

Grounded in the chezmoi `scripts/` Nim tooling. Defer Nim *idioms*, NEP-1, and
`nph` specifics to the **`writing-nim-code`** skill; this reference owns layout +
dependencies + the gate.

Nim is the **single-purpose, non-trivial script tier** of the ladder (above
bash/just, below Rust). Two project shapes:

## Shape A — a tool that compiles to `~/.local/bin/` (the dominant pattern)

Source lives in `scripts/<domain>/name.nim`; the binary installs to
`~/.local/bin/name`.

- **Filenames must be valid Nim identifiers** — `image_sort.nim` (underscores),
  never `image-sort.nim`. The binary `-o:` name *may* use hyphens (`image-sort`).
- **Canonical compile** (his invocation): `nim c -d:release --opt:size --hints:off
  -o:"$HOME/.local/bin/name" path/to/source.nim`. Add `-d:ssl` if it makes HTTPS
  requests.
- **In a chezmoi repo:** register the build in `run_onchange_build-scripts.sh.tmpl`
  with a `# source hash: {{ include … | sha256sum }}` line so chezmoi rebuilds on
  edit, guarded by `command -v nim` (skip cleanly if the compiler is absent) and a
  `nimble path <dep> || nimble install -y <dep>` guard per dependency.
- **Standalone repo:** a `justfile` `build` recipe running the same `nim c`.

## Shape B — a distributable nimble package

`nimble init` → `name.nimble` + `src/` + `tests/`. Use this only when publishing
or when the project outgrows a single file. Tests via `testament` or `nim c -r`.

## Don't reinvent the wheel (Nim reaches)

| Need | Reach for | Note |
|------|-----------|------|
| CLI args / subcommands | **`cligen`** (`dispatch` / `dispatchMulti`) | install-guard pattern before `nim c` |
| JSON from external sources | **`json_serialization`** (status-im) with typed `Option[T]` | NOT `std/json` — see the `feedback_nim_json_serialization` convention |
| HTTP(S) | `std/httpclient` + `-d:ssl` | |

Install deps with `nimble install -y <pkg>`.

## Quality gate

- **Format:** `nph` (NEP-1; lives in `~/.nimble/bin`, on PATH after zshrc). Gate:
  `nph --check <files>`.
- **Static analysis / type-check:** the Nim compiler *is* the type checker. Gate
  with `nim check --styleCheck:error <entry>.nim` — `--styleCheck:error` enforces
  NEP-1 naming as a hard failure. (Builds use `--hints:off` for quiet output; the
  lint gate wants the checks loud.)
- **Max-file-length:** Nim has no complexity or length lint. Use the shared
  `wc -l` hook (`assets/check-file-lines.sh`) with `files = '\.nim$'`.
- **Tests:** `std/unittest`, run `nim c -r tests/test_name.nim`. TDD: Red →
  verify-red → minimal green → commit at GREEN.

### `prek.toml` (Nim)

```toml
[[repos]]
repo = "builtin"
hooks = [
  { id = "trailing-whitespace" },
  { id = "end-of-file-fixer" },
  { id = "check-merge-conflict" },
  { id = "detect-private-key" },
]

[[repos]]
repo = "local"

[[repos.hooks]]
id = "nph-check"
name = "nph --check"
entry = "nph --check"
language = "system"
files = '\.nim$'
stages = ["pre-commit"]

[[repos.hooks]]
id = "nim-check"
name = "nim check --styleCheck:error"
entry = "nim check --styleCheck:error --hints:off"
language = "system"
files = '\.nim$'
stages = ["pre-commit"]

[[repos.hooks]]
id = "file-line-limit"
name = "file line limit"
entry = "scripts/check-file-lines.sh"
language = "script"
files = '\.nim$'
stages = ["pre-commit"]
```

## `justfile` spine

```just
fmt:
    nph $(fd -e nim)

fmt-check:
    nph --check $(fd -e nim)

check-types:
    nim check --styleCheck:error --hints:off src/main.nim

test:
    nim c -r tests/test_main.nim

check: fmt-check check-types test
```

## Gotchas (this environment)

- **Underscores in source filenames, hyphens allowed in binary names.**
- `std/re` can't compile patterns at `const` time (Nim 2.2+) — use `let` for
  module-level regex.
- `std/md5` is deprecated (Nim 2.2+) — wrap the import in `{.push warning[Deprecated]: off.}`
  / `{.pop.}` or take the `checksums` dep.
- It's **`nph`**, not `nimpretty`.
