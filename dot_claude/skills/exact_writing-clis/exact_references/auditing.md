# Auditing an Existing CLI

The generic procedure for reviewing any CLI — house tool or third-party — against
the canon. Cite rules, not vibes: every finding names a floor item number, a
tier item, a POSIX guideline, or a reference-file rule.

## Procedure

### 1. Inventory the surface

Walk the `--help` tree: root help, then every subcommand's help, recursively.
Build a table: subcommand → flags (short, long, takes-value?, default) →
positionals. This table is the audit's raw material; nothing else in the
procedure works without it. For tools with a skill or README, diff the
documented surface against the actual one — undocumented flags and doc-only
flags are both findings.

### 2. Grammar pass

Against SKILL.md §Command grammar, hunt for:

- **Mixed bare/namespaced verbs at root** (`tool stop <id>` next to
  `tool daemon stop`)
- **Flag/subcommand homonyms** (`tool schema` + `--schema`)
- **Position-sensitive flags** ("only binds before X") — wrapper exception only
  for foreign argv tails
- **Packed heterogeneous values** (`--audio-output alloy:wav`)
- **Root-flag accretion** — flags on the root command that belong to one
  implicit action (the promote-to-verb fix)
- Near-synonym subcommands (`update`/`upgrade`), `*-list` duplicates of a bare
  noun, inconsistent verbs across nouns

### 3. Floor pass

The 10 floor items (SKILL.md) as a table: item · pass/fail · evidence. Evidence
is a command you ran or a line you read, not an assumption — run the tool to
check, don't trust the docs. Gather evidence safely: prefer read-only/no-op
invocations (`--help`, `--dry-run`, list commands) and fixture inputs; never
exercise a mutating or destructive command against real state to tick a box.

### 4. Tier pass (if installed and long-lived)

Same table for the full-tier items. A missing `--json` on a data-emitting tool
and a missing `NO_COLOR` check are the two most common finds.

### 5. Output-discipline spot checks

- Run a representative command **piped** (`tool … | cat`): what lands on stdout
  vs stderr? Payload-only on stdout is the pass condition.
- Run `--json` output through `jaq .` — it must parse, and stderr noise must not
  be interleaved.
- Run with `NO_COLOR=1` and piped: any escape codes left is a fail.
- If automation-invoked (Hazel/launchd): run the routine no-op case; stdout must
  be empty and the exit code 0.

### 6. Config and paths check

- `rg` the source (or `strings` the binary) for hardcoded `~/.<name>`,
  `~/Library`, `/tmp` paths — XDG violations.
- Verify the precedence chain (flag > env > config > default) is documented and
  real: set a config value, override with env, override with flag.
- Check env vars are tool-prefixed with generic fallback.
- Secrets: any flag or config field that holds a secret value is an automatic
  top-severity finding (`secrets.md`).

### 7. Emit the violations worklist

One finding per line: **rule cited · evidence · proposed fix**, ordered by user
pain:

1. **Grammar** (breaks muscle memory and composability; hardest to fix later —
   fix first while the blast radius is small)
2. **Output discipline** (breaks pipelines and automation hosts)
3. **Naming** (collisions and homonyms; renames get more expensive every week)
4. **Config/paths** (annoying, migratable)

Fixes that change existing invocations note the migration path (alias the old
form for a deprecation window, or state that breaking is acceptable and why).

## First customer: `lu`

The audit that motivated this canon. Known suspects to start from (verify each
against the procedure above rather than assuming):

- Root grammar: bare verbs coexisting with namespaced subcommands
- `lu schema` subcommand vs `--schema` flag homonym
- `--strip`/`--no-strip` tri-state flag sprawl
- `--no-tools` binding only before `config` (position sensitivity)
- `--audio-output alloy:wav` packed value
- Root-flag accretion from the born-headless era — the fix pattern is the
  accretion rule: promote the implicit run behavior to `lu run` and move its
  flags there
