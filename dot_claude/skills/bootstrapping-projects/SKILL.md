---
name: bootstrapping-projects
description: >-
  Use when starting, bootstrapping, scaffolding, or initializing a new project,
  package, or repo — or adding a new language/crate/module to an existing one —
  to structure it the way Alex likes. Wires a formatter, linter, and
  static-analysis/type-checker in BEFORE the first feature; sets strict
  complexity and file-size caps to stop AI-driven sprawl; installs a prek
  pre-commit gate and a just task runner; enforces TDD; and reaches for
  well-liked third-party packages instead of reinventing the wheel. Triggers on
  "new Rust/Swift/iOS/Nim/Python project", "bootstrap a repo", "scaffold a
  crate", "set up a new package", "start a project", "init this repo", "spin up a
  new app", or any greenfield setup. Routes to per-stack references (rust,
  swift-ios, nim, python) and the deep language skills (writing-nim-code,
  building-swiftui-views, pfw-*, pi-agent-rust).
---

# Bootstrapping New Projects

Stand up a new project (or a new language surface inside an existing repo) with
Alex's conventions baked in from the first commit — so the guardrails exist
*before* there's any code to sprawl. This skill owns the **scaffolding decision**
(layout, default dependencies, the quality gate); it does **not** re-teach the
languages — it routes to the deep skills for that.

## The thesis (read this first — it's why the skill exists)

AI agents sprawl. Left unconstrained they write 1,200-line files, 9-argument
functions, and deeply nested logic — code that passes tests and is miserable to
maintain. **The fix is mechanical, not motivational:** wire in a formatter, a
linter at an almost-annoyingly-strict level, a static-analysis/type-check pass,
and hard caps on complexity and file size — and put them on a pre-commit gate so
nothing lands that violates them.

The strictness is the point. Pick lint levels *stricter than a human would
hand-tune for themselves* (clippy `pedantic`, complexity thresholds, file-length
caps), because the constraint is what stops the sprawl. A rule that occasionally
annoys you is doing its job.

## The universal invariant (every project, every language — unless Alex says otherwise)

Every new project gets ALL of these wired in **before the first feature**:

1. **Formatter** — one canonical formatter, config committed, runs in the gate.
2. **Linter at a strict level** — warnings are errors (`-D warnings` / equivalent).
3. **Static analysis / type-checking** — the language's strongest available pass.
4. **Complexity + size caps** — function complexity, argument count, and a
   **max-file-length** cap. (Function-level caps are usually native to the
   linter; file-length usually is not — the stack reference names the tool.)
5. **Pre-commit gate via `prek`** — formatter-check + lint + caps + hygiene
   hooks (trailing-whitespace, eof-fixer, large-files, merge-conflict,
   **detect-private-key**). Never bypass with `--no-verify`.
6. **`just` task runner** — a `check` recipe (`fmt-check` + `lint` + `test`) that
   is the single local gate; CI runs *the same just recipes* (one source of flags).
7. **TDD** — Red → verify-red → minimal green → commit at GREEN. Every GREEN
   commit is warning-clean.
8. **Repo hygiene** — `README`, `LICENSE` (MIT default), `.gitignore`, an
   `AGENTS.md` (or `CLAUDE.md`) capturing the conventions for future agents.

If a project legitimately can't have one of these, say so explicitly and say why
— don't silently skip it.

## Don't reinvent the wheel

Before writing a utility, check whether the ecosystem already has a well-liked
one. Reach for the package the community trusts; don't hand-roll argument
parsing, error types, date math, JSON handling, HTTP, etc.

- **Verify current choices** with the `find-docs` skill / `ctx7` CLI — don't pick
  a crate/package from stale memory. Popularity and maintenance status change.
- **Each stack reference lists the default dependencies** Alex reaches for — start
  there, deviate with reason.
- **The exception:** don't pull a heavy dependency for a five-line helper, and
  don't add a dependency you can't justify. "Well-liked" ≠ "always worth the weight."

## Procedure

1. **Orient.** `ls`/`eza` the target dir. Greenfield, or a new surface in an
   existing repo? Which stack? Confirm before scaffolding into a non-empty dir.
2. **Load the stack reference** (table below) and the relevant deep skill.
3. **Scaffold the skeleton** — directory layout + all config files (formatter,
   linter, complexity/size caps, toolchain pin) from the reference. No features yet.
4. **Wire the gate** — write `prek.toml`, the `justfile` (`check` recipe), install
   the hooks (`prek install` / the documented step). Add a minimal CI workflow
   that calls the same just recipes.
5. **Prove the gate is real** — run `just check` and `prek run --all-files` on the
   *empty skeleton*. It must pass clean. A gate you never ran is not a gate.
6. **First feature via TDD** — Red → green → commit at GREEN, gate enforced, never
   `--no-verify`.

## Stack router (load the reference on demand)

| Stack | Reference | Deep skill(s) to also load |
|-------|-----------|----------------------------|
| **Rust** | `references/rust.md` | `pi-agent-rust` |
| **Swift / iOS** | `references/swift-ios.md` | `building-swiftui-views`, `pfw-*` (TCA, dependencies, sqlite-data, sharing, …) |
| **Nim** | `references/nim.md` | `writing-nim-code` |
| **Python** | `references/python-guardrails.md` | — (Python is last-resort; the reference is mostly "don't") |

Glue skills, any stack: **`prek`** (pre-commit gate), **`writing-justfiles`**
(the task runner), **`writing-mise-tasks`** (if tasks live in mise instead).

## Gotchas

- **`prek`, not `pre-commit`.** Same `.pre-commit-config.yaml`-style config but
  Alex uses `prek` (Rust, faster). Config lives in `prek.toml`. Load the `prek` skill.
- **Never `--no-verify` / `--no-gpg-sign`** to dodge the gate. If the gate is
  wrong, fix the gate.
- **Run the gate on the empty skeleton** before feature #1. The most common
  failure is shipping a `prek.toml` that was never executed and is subtly broken.
- **Don't duplicate the deep skills.** This skill picks layout + dependencies +
  the gate; `writing-nim-code` / `building-swiftui-views` / `pfw-*` own the
  language idioms. Route, don't restate.
- **Max-file-length is usually not a native lint.** Most linters cap *function*
  length, not *file* length. The stack reference names the concrete file-length
  mechanism — wire it in; it's the headline anti-sprawl rule.
- **One source of flag truth.** CI calls the same `just` recipes as local. Don't
  let CI and the pre-commit gate drift into two different lint invocations.
