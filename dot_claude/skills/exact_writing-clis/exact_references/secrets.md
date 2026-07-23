# Secrets

Precedence: house policy (the env floor), with the clig deviation acknowledged
explicitly. Short file on purpose — the rules are few and absolute.

## The env floor (every tool, today)

- **Secrets come from environment variables only.** Never flags, never config
  fields.
- **Tool-prefixed var beats generic**: `SPEAK_ELEVENLABS_API_KEY` >
  `ELEVENLABS_API_KEY`, `TOKENS_ANTHROPIC_API_KEY` > `ANTHROPIC_API_KEY`. The
  prefix exists so one tool's key can differ from (or avoid clobbering) another
  consumer of the generic name.
- **Never a flag** — argv is world-readable via `ps`, lands in shell history,
  and creeps into `--help` examples. The origin story: elevenlabs-cli leaked its
  key into its own `--help` output; `speak` was built so "there is nothing for
  `--help` to leak" — it reads keys from the environment ONLY.
- **Never a config field** — speak's `config.toml` has no key field *at all*.
  A field that exists will eventually be committed.
- **Never echoed** — on a missing key, fail naming the *variable*, never its
  value, and never print a partial ("sk-ab…"). lu's rule: don't even read the
  var just to check it; let the failing call fail and report the var name.
- `--password $(< pw.txt)`-style substitution is NOT a workaround — the value
  still lands in argv.

## The file path (new long-lived tools)

Tools graduating to the full tier grow **file-based resolution alongside the env
floor**:

- `--key-file <path>` (a path is not a secret — fine as a flag), or a documented
  credential file at `$XDG_CONFIG_HOME/<tool>/credentials` with mode **0600**.
  Validate before reading, either source: a regular file, owned by the current
  user, mode 0600 — reject anything else.
- The curl model: `-H @filename` reads the sensitive header from a file instead
  of argv.
- Resolution order: `--key-file` > `<TOOL>_<PROVIDER>_API_KEY` > generic var.
- Password prompts (interactive only) disable terminal echo.

## DEVIATION from clig

clig says **never env vars either**: exported vars propagate to every child
process, and `docker inspect` / `systemctl show` expose a unit's environment.
That's a real leak surface and the reason this is marked as a deviation, not a
disagreement. The house position: on a single-user machine the env floor is an
acceptable trade against the ergonomics cliff of mandatory credential files —
and the file path above is the mitigation that kicks in as tools graduate. For
anything that runs under a service manager or spawns untrusted children, treat
clig's rule as binding and go file-based from day one.

**Hard boundary (unchanged by any of this): 1Password holds Alex's secrets and
is never accessed programmatically.**

## Checklist (for audits)

- [ ] No secret-valued flags; no secret fields in config files
- [ ] Env lookup: tool-prefixed first, generic fallback
- [ ] Missing key → error names the variable, never a value, no partials
- [ ] Full tier: `--key-file`/credential-file path exists, 0600
- [ ] Service-managed / child-spawning tools: file-based only
