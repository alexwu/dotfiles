# Errors and Robustness

Precedence: clig.dev spine; exit-code canon is house + coreutils convention;
fail-closed/soft-fail split is a house doctrine cited to real tools.

## Error style

- **Catch expected errors and rewrite for humans** (clig's canonical example):
  "Can't write to file.txt. You might need to make it writable by running
  'chmod +w file.txt'." Name the problem AND the likely fix.
- **Name the tool**: every error line starts with the tool's own name —
  `myapp: can't write to file.txt`. House pattern: a per-binary `fail()` proc
  that prefixes, prints to stderr, and quits 1.
- **Most important info last** — it's what sits above the next prompt.
- **Group repeated errors** under one explanatory header instead of spamming
  N near-identical lines (signal-to-noise).
- Unexpected errors: point at debug info or a bug-report path; consider writing
  the full traceback to a file rather than dumping it on the terminal. No scary
  stack traces for *expected* failures, ever.

## Exit-code canon (floor rule 3, expanded)

| Code | Meaning | Notes |
|---|---|---|
| 0 | success | also "not my job" skips — see below |
| 1 | runtime failure | the underlying error body surfaced verbatim on stderr, never swallowed |
| 2 | usage / precondition error | caught before any side effect or network call |
| 124 | wrapped command timed out | wrapper CLIs; `timeout(1)` convention (house: wezrun) |
| 125 | wrapper's own setup failed | `env(1)` convention (house: wezrun) |
| N | wrapped command's own code | wrappers pass it through untouched |

**The Hazel skip-vs-fail split** (house, image-sort precedent): "this input isn't
mine to process" is a *skip* — stderr note + **exit 0** — not a failure. A
nonzero exit surfaces in Hazel as "Shell script failed" and triggers a wrong
retry. Any tool invoked by an automation host needs the same audit: which of its
non-successes are failures, and which are polite declines?

## Failure discipline

- **Fail before side effects**: validate everything validatable, then act. A
  usage error (exit 2) must never leave partial state behind.
- **Fail-closed for anything gating an action** (house doctrine): a guard whose
  classifier is missing or errors degrades to *deny*, never allow
  (truncation-guard precedent). "An unavailable classifier must never silently
  allow."
- **Soft-fail for non-critical metadata** (house, image-sort): a frame-count or
  dimensions read that fails degrades to a default — "a frame-count miss must
  never abort the sort." The split: does the value *gate a decision* (fail
  closed) or *decorate one* (degrade gracefully)?
- A config-reference typo must never silently disable behavior — fall through
  loudly or error (anchor-manifest precedent; full rule in config-and-state.md).

## Responsiveness

- **Print something within 100ms** — responsiveness beats raw speed; a silent
  tool reads as hung.
- **Print before the network call starts**, not after it returns.
- Progress indication for anything long; a stalled indicator must not look like
  a crash.

## Network and time

- Configurable timeouts with a sane default. **Never hang forever** — every
  blocking operation has a bound.
- Transient failure + re-run = clean resume or retry (idempotency as a design
  goal). Crash-only design: avoid *needing* cleanup; tolerate starting in a
  state where prior cleanup never ran.

## Signals

- Ctrl-C (SIGINT) always works, even mid network I/O. Exit ASAP; print an
  acknowledgment before cleanup; cap cleanup with a timeout.
- Second Ctrl-C during cleanup = force-stop. The docker-compose model:
  "Gracefully stopping... (press Ctrl+C again to force)".
- Wrapped-execution tools document their escape mechanism. Don't be vim.

## Expect misuse

Piped into scripts, dead connections, concurrent instances of yourself, and —
locally load-bearing — **macOS's case-insensitive-but-preserving filesystem**:
`Foo.txt` and `foo.txt` are the same file here and different files in CI. Never
rely on case to distinguish paths.

## Checklist (for audits)

- [ ] Errors: tool-name prefix, human rewrite with suggested fix, stderr, info-last
- [ ] Exit codes: 0/1/2 split honored; wrappers pass through + 124/125
- [ ] Automation-host tools: skips exit 0, failures exit nonzero — audited case by case
- [ ] Validation precedes side effects; exit-2 paths leave no partial state
- [ ] Gating values fail closed; decorative values degrade gracefully
- [ ] First output <100ms; output precedes network calls
- [ ] All blocking operations bounded; re-run after transient failure is clean
- [ ] Ctrl-C exits fast; second Ctrl-C force-stops
