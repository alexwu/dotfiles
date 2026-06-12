# Using Scripts in Skills

Skills can instruct the agent to run shell commands and bundle reusable helpers in `scripts/`. Load this when a skill needs bundled executable logic. Covers when to bundle, the **language policy**, organizing helpers as `just` recipes, and — most importantly — designing scripts an agent can drive.

## Inline command vs. bundled script

- **Inline a command** in `SKILL.md` when an existing tool already does the job with a few flags. No `scripts/` directory needed.
- **Bundle a script** when the command grows complex enough that it's hard to get right first try, or when execution traces show the agent **reinventing the same logic** every run (parsing a format, building a chart, validating output). Write it once, test it, bundle it.

## Language policy

The right amount of tooling is the minimum that does the job. Climb this ladder only as complexity demands:

| Complexity | Use | Notes |
|------------|-----|-------|
| Trivial (a few lines) | **bash**, ideally a **`just` recipe** | Bash *orchestrates* fast binaries (`rg`, `fd`, `jaq`, `ast-grep`, compiled tools) — it never reimplements logic in shell |
| Single-purpose, non-trivial | **Nim** | NEP-1 style, format with `nph`, `cligen` for args; source in `scripts/`, compiled |
| Structured-data pipeline | **nushell** | When typed tables/records make the transform clearer than text-mangling |
| One-off pinned tool invocation | **`go run pkg@version`** | Built into Go, no extra tooling; pin the version |
| Complex / performance-sensitive / long-lived | **stop — propose a Rust CLI and discuss first** | Don't grow a script into a system silently |

**Not options here:** Python, JavaScript/TypeScript, Ruby — and by extension their runners (`uvx`, `pipx`, `npx`, `bunx`, `deno run`, `bundler/inline`, PEP-723 inline scripts). The upstream agentskills.io scripts guide recommends several of those; in this environment they're deliberately excluded. If a third-party SDK genuinely forces an interpreted runtime, raise it explicitly rather than reaching for it by default.

State prerequisites in `SKILL.md` ("Requires `just` and `rg` on PATH") rather than assuming them; use the `compatibility` frontmatter field for runtime-level requirements.

## Organize helpers as `just` recipes

When a skill has more than one helper command, prefer a `justfile` over a scatter of loose wrapper scripts. The recipes become the documented, named interface; `SKILL.md` lists `just <recipe>` invocations and the agent runs them. This keeps argument handling and orchestration in one tested place instead of duplicated across the body.

```
## Available commands
- `just analyze <input>`   — analyze the input, emit a plan as JSON
- `just validate <plan>`   — validate the plan against the source of truth
- `just apply <plan>`      — execute a validated plan
```

A recipe can shell out to a compiled Nim/Rust helper in `scripts/` for the heavy lifting — bash/just for orchestration, the binary for logic.

## `go run` for one-off pinned tools

When you just need to invoke an existing tool and don't want to vendor it, `go run` compiles and runs it directly — built into Go, version-pinned:

```
go run golang.org/x/tools/cmd/goimports@v0.28.0 .
go run github.com/golangci/golangci-lint/cmd/golangci-lint@v1.62.0 run
```

Pin the version (or use `@latest` if you explicitly want floating) so the command behaves the same over time. Once the invocation grows beyond a few flags, move it into a tested script.

## Referencing scripts from `SKILL.md`

Use **relative paths from the skill root** — the agent resolves them automatically, runs commands from the skill root, and no absolute paths are needed. List what exists so the agent knows it's there:

````markdown
## Available scripts
- **`scripts/validate`** — validates configuration files
- **`scripts/analyze`** — analyzes input data, emits JSON

## Workflow
1. Validate:
   ```bash
   scripts/validate "$INPUT_FILE"
   ```
2. Analyze the result:
   ```bash
   scripts/analyze --input results.json
   ```
````

The same relative-path convention applies in `references/*.md`. Keep references one level deep.

## Designing scripts for agentic use

The agent reads stdout/stderr to decide its next move. These choices make a script dramatically easier to drive — they apply regardless of language.

### Avoid interactive prompts (hard requirement)

Agents run in non-interactive shells — they cannot answer TTY prompts, password dialogs, or confirmation menus. A script that blocks on input **hangs indefinitely**. Take all input via flags, environment variables, or stdin:

```
# Bad: hangs waiting for input
$ scripts/deploy
Target environment: _

# Good: fails fast with guidance
$ scripts/deploy
Error: --env is required. Options: development, staging, production.
Usage: scripts/deploy --env staging --tag v1.2.3
```

### Document usage with `--help`

`--help` is how the agent learns the interface. Brief description, flags, examples — kept concise, since it lands in the agent's context:

```
Usage: scripts/process [OPTIONS] INPUT_FILE

Process input data and produce a summary report.

Options:
  --format FORMAT   Output: json, csv, table (default: json)
  --output FILE     Write to FILE instead of stdout
  --verbose         Progress to stderr

Examples:
  scripts/process data.csv
  scripts/process --format csv --output report.csv data.csv
```

### Write helpful error messages

The error message shapes the agent's next attempt. Say what went wrong, what was expected, what to try:

```
Error: --format must be one of: json, csv, table.
       Received: "xml"
```

### Use structured output

Prefer JSON / CSV / TSV over free-form text — consumable by the agent *and* by `jaq`, `cut`, `awk`, so the script composes in pipelines:

```
# Whitespace-aligned — hard to parse
NAME        STATUS   CREATED
my-service  running  2025-01-15

# Delimited — unambiguous
{"name":"my-service","status":"running","created":"2025-01-15"}
```

**Separate data from diagnostics:** structured data to **stdout**, progress/warnings/diagnostics to **stderr**. The agent captures clean parseable output while diagnostics stay available.

### Further considerations

- **Idempotency** — agents retry. "Create if not exists" beats "create and fail on duplicate."
- **Input constraints** — reject ambiguous input with a clear error instead of guessing. Prefer enums / closed sets.
- **Dry-run** — a `--dry-run` flag lets the agent preview destructive or stateful operations.
- **Meaningful exit codes** — distinct codes per failure class (not-found, bad-args, auth), documented in `--help`.
- **Safe defaults** — gate destructive operations behind `--confirm` / `--force` as the risk warrants.
- **Predictable output size** — many harnesses truncate tool output past a threshold (~10–30K chars), losing information silently. If output can be large, default to a summary or limit and support `--offset` for more, or require an `--output FILE` (with `-` to opt into stdout explicitly).
