# Arguments and Flags

Precedence: clig.dev spine; POSIX.1-2017 §12.2 cited by guideline number (G-numbers);
Heroku for the flags-over-args argument; house amendments marked `DEVIATION:`.
Note: long options (`--foo`) are GNU getopt_long, not POSIX — G-numbers only govern
short options, option-arguments, and operands.

## Flags over args

Prefer flags to positional arguments: clearer intent, order-independent, better
error messages, easier to extend without breaking compatibility (clig + Heroku).

Heroku's canonical example:

```
# Bad — which app is source, which is destination?
heroku fork destapp -a sourceapp

# Good — self-documenting
heroku fork --from sourceapp --to destapp
```

**The single-obvious-arg exception**: one positional is fine when it's the
obvious primary object — `heroku access:add user@example.com --privileges deploy`
(the email is bare, the modifier is a flag). Multiple positionals are fine for a
*list of the same thing* (`rm a.txt b.txt`). Two-plus positionals with *different
meanings* is a design smell (clig) — the one grandfathered shape is a single
memorable primary action like `cp <src> <dst>`.

## Standard flag names

Use the standard name when the concept matches — never invent a synonym for a
flag users already know. clig's table merged with house short-flag conventions:

| Flag | Meaning | Notes |
|---|---|---|
| `-a, --all` | all items | |
| `-d, --debug` | debug output | |
| `-f, --force` | skip confirmation | mild/moderate tiers only — severe still requires the typed name / `--confirm=<name>` |
| `--json` | structured output | full tier |
| `-h, --help` | help | never anything else |
| `-n, --dry-run` | simulate | house: `-n` is dry-run, not "count" |
| `--no-input` | disable all prompting | |
| `-o, --output` | output path | |
| `-p, --port` | port | |
| house: `-p, --provider` | provider (`tokens -p local`) | domain-compat rebind of `-p` |
| `-q, --quiet` | suppress non-error output | |
| `-u, --user` | user | |
| `-v, --verbose` | verbose, repeatable (`-vv`) | see ruling below |
| `-V, --version` | version | |
| house: `-m, --model` | model | `tokens -m`, `speak --model` |
| house: `-i, --input` | input | |
| house: `-j, --jobs` | jobs/parallelism | |

**The `-v` ruling** (house, settled 2026-07-14): `-v` = verbose (repeatable),
`-V --version` = version. The `-V --version` binding is clap's default and what
installed rg, cargo, fd, bat, delta, and jaq all bind; repeatable `-v` is the
house convention and needs explicit wiring (clap `ArgAction::Count`).
Domain-compat exceptions allowed where a tool inherits a meaning (rg `-v` =
invert-match, from grep). clig calls `-v` contested; the ruling settles it
locally.

## POSIX mechanics (cited by guideline)

- **G4/G3**: options are `-` + a single alphanumeric; `-W` is reserved for vendors.
- **G5**: no-arg short options group behind one dash (`-abc`), plus at most one
  option-taking option at the end of the group (`-abcp arg`). Any parser worth
  using (cligen, clap) gives this free.
- **G6**: option and option-argument are separate argv entries (`-c foo`), though
  implementations must also accept the glued form (`-cfoo`).
- **G7**: **option-arguments are never optional.** A flag either always takes a
  value or never does. `--color[=WHEN]`-style optional values create parse
  ambiguity — if you need "on/off/auto", make the value mandatory or use a
  sentinel (below).
- **G8**: multiple values to one option = one argument with comma (or blank)
  separators — `--tags a,b,c`. This is the sanctioned multi-value form;
  repetition (`--tag a --tag b`) is the GNU-style alternative, also fine.
  `DEVIATION` boundary: what's NOT fine is packing *heterogeneous* values into
  one token (`--audio-output alloy:wav` — a voice AND a format). Separate flags.
- **G9**: options precede operands. **G11**: option order must not matter; a
  repeated value-taking option is interpreted in command-line order.
- **G10**: the first `--` ends options; everything after is an operand even if it
  starts with `-`. Always honored, always documented.
- **G13**: where a file operand is expected, `-` means stdin (or stdout in an
  output slot).
- **G14**: anything that parses as an option is treated as one — don't invent
  "this dash-token is secretly an operand" cases.

## The wrapper-CLI exception (house)

G9/G11 have one sanctioned house exception: **wrapper CLIs** (memo, chain,
wezrun) whose job is to run *another* command. The wrapped command is an opaque
argv tail: wrapper flags come first, and once the wrapped command's name starts,
every later token belongs to it. `--` makes the boundary explicit and is the
form docs must show:

```
memo --tail 40 -- just build     # ✓ explicit boundary
memo --tail 40 just build        # ✓ shorthand
memo just build --tail 40        # ✗ --tail is handed to `just build`
```

A **dispatcher is not a wrapper** — `lu` dispatching to its own subcommands gets
no exemption; its flags must bind order-independently. The test: does the tail
belong to a *foreign* command? Only then does the exception apply.

## Repeatable flags

A repeated option is interpreted in command-line order (G11). Repeatable `-v`
escalates verbosity (`-vv`). A repeated no-argument option that *isn't* meant to
stack is undefined per POSIX 12.1 — reject or document it.

## Prompts

- **Never require a prompt** (Heroku hard rule): every interactive prompt has a
  flag/arg path that bypasses it (`heroku keys:add /path/to/key` skips the picker).
- Prompt only when stdin is a tty. Off-tty with required input missing → error
  with instructions, don't hang.
- `--no-input` hard-disables all prompting.
- Expected-stdin-but-got-a-tty → print help and exit; don't sit there like `cat`.
- Typo suggestions ("did you mean X?") ask before running — never auto-correct
  and execute (clig: auto-running creates an implicit commitment to support the
  wrong syntax forever).

## Destructive actions (tiered, clig + house)

| Tier | Example | Requirement |
|---|---|---|
| Mild | delete one file | confirmation optional if the command name signals danger |
| Moderate | delete a dir, remote change, bulk edit | confirm by default; offer `--dry-run` |
| Severe | delete a remote app / whole dataset | require typing the resource's name; `--confirm=<name>` for scripts |

Non-obvious destructive *side effects* count as severe. The house addition
(gif-mosaic precedent): a guard-rail refusal names **both the limit and the exact
bypass flag** — "input exceeds 200MB; pass --force to proceed anyway."

## Sentinel words over blank optionals

Because of G7, a flag can't have an optional value. When "explicitly none" is a
meaningful choice, use a sentinel word: `--footer=none` (memo precedent), not a
bare `--footer` with implied emptiness.

## Secrets

**Never accept a secret via flag** — argv leaks into `ps`, shell history, and
`--help` examples. `--password $(< pw.txt)` is still insecure (same argv). This
is floor rule 5; the full policy (env floor, `--key-file` path) lives in
`secrets.md`.

## Checklist (for audits)

- [ ] Flags preferred; positionals only single-obvious or same-thing lists
- [ ] Standard names used where concepts match; `-v`/`-V` per ruling
- [ ] Every flag has a long form; short forms only for frequent flags
- [ ] No optional option-values (G7); sentinels for explicit-none
- [ ] No heterogeneous packed values; G8 comma-lists or repetition for multi
- [ ] Flags order-independent (G9/G11) — wrapper exception only for foreign tails
- [ ] `--` honored (G10); `-` = stdin/stdout where file operands occur (G13)
- [ ] Every prompt flag-bypassable; no prompting off-tty; `--no-input` present (full tier)
- [ ] Destructive actions tiered; refusals name limit + bypass flag
- [ ] No secrets in flags
