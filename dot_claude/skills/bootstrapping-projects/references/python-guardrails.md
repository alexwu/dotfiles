# Python — guardrails ("don't, but if you must")

Python is the **last resort** of the scripting ladder. This reference is mostly a
list of things *not* to do. Read the STOP gate before writing a line of Python.

## STOP — is Python even allowed here?

Before reaching for Python, walk the ladder:

| Need | Use instead |
|------|-------------|
| Trivial glue (a few lines) | bash, ideally a `just` recipe |
| Single-purpose, non-trivial CLI | **Nim** (`references/nim.md`) |
| Complex / performance-sensitive / long-lived | **Rust** (propose first) |
| A quick one-off | `go run` |

**Python is justified ONLY when a specific library or SDK forces it** — an ML /
inference stack (mlx, voxtral, torch), or a vendor SDK with no equivalent in
another language. "I'm faster in Python" is **not** a reason. If a hot path is
involved (e.g. a Claude Code hook), Python is **disqualified** — interpreter
startup tanks the UX; use Nim.

## NEVER (the hard "don't ever do this" list)

- ❌ A **non-`uv`** workflow. No bare `pip install`, no hand-rolled `venv`, no
  global site-packages, no conda / poetry / pipenv / pdm. **`uv` only.**
- ❌ A `requirements.txt` for a single-file script — use **PEP 723 inline
  metadata** + `uv run --script`.
- ❌ Committing without the formatter / linter / type-checker because "it's just a
  script." The gate applies to Python too.
- ❌ Untyped code. No type hints = no merge.

## IF UNAVOIDABLE — the uv + Astral stack

**Dependencies & running**

- **Project:** `uv init`, a `pyproject.toml`, and a committed `uv.lock`.
- **Single-file script:** PEP 723 inline deps, no separate requirements file:

  ```python
  # /// script
  # requires-python = ">=3.13"
  # dependencies = ["httpx"]
  # ///
  ```

  Run with `uv run --script foo.py`. (This is the `dictate.py` pattern.)

**Format & lint — `ruff`**

- **Format with `ruff format`** (and `ruff format --check` in the gate).
- **Lint with `ruff check`** at a strict ruleset — one tool does both.

  ```toml
  [tool.ruff]
  line-length = 100

  [tool.ruff.lint]
  select = ["E", "F", "I", "UP", "B", "SIM", "PL", "RUF"]
  ```

**Type-check (non-negotiable, even for scripts)**

- Default to **`basedpyright --strict`** (the stricter pyright fork). It is the
  only checker that enforces **annotation completeness** — missing param/return
  types and `Unknown` leaks all fail the gate, which is exactly the anti-sprawl
  contract.
- **Not `ty` (Astral), despite the ecosystem pull (as of mid-2026).** ty's
  *gradual guarantee* means it deliberately won't flag unannotated code — there is
  no `--strict` equivalent and none is planned, so it cannot be a strict annotation
  gate. It's also still Beta (panics in recent releases). Revisit only once ty
  ships Stable **and** annotation-enforcement rules (watch the milestone page /
  ruff gaining type-aware rules).
- **Not `pyrefly` (Meta)** either: it's stable (1.0+) and stricter-by-inference
  than ty, but brings zero uv/ruff integration gain and still lacks a
  basedpyright-equivalent strict annotation mode — no reason to split tooling.
- Re-verify this call with `find-docs` if it's been a while; these checkers move fast.

**Max-file-length** — `ruff` has no file-length rule (`E501` is *line* length).
Use the shared `wc -l` hook (`assets/check-file-lines.sh`, `files = '\.py$'`).
Native alternative if you already run pylint: `C0302` (`max-module-lines`).

**Tests** — `pytest`, TDD.

### `prek.toml` (Python)

```toml
[[repos]]
repo = "local"

[[repos.hooks]]
id = "ruff-format"
name = "ruff format --check"
entry = "ruff format --check"
language = "system"
files = '\.py$'
stages = ["pre-commit"]

[[repos.hooks]]
id = "ruff-check"
name = "ruff check"
entry = "ruff check"
language = "system"
files = '\.py$'
stages = ["pre-commit"]

[[repos.hooks]]
id = "basedpyright"
name = "basedpyright --strict"
entry = "basedpyright --strict"
language = "system"
files = '\.py$'
pass_filenames = false
stages = ["pre-commit"]

[[repos.hooks]]
id = "file-line-limit"
name = "file line limit"
entry = "scripts/check-file-lines.sh"
language = "script"
files = '\.py$'
stages = ["pre-commit"]
```

## `justfile` spine

```just
fmt:
    uv run ruff format .

fmt-check:
    uv run ruff format --check .

lint:
    uv run ruff check .

typecheck:
    uv run basedpyright --strict

test:
    uv run pytest

check: fmt-check lint typecheck test
```
