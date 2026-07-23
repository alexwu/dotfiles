# Output

Precedence: clig.dev spine; Heroku for the two-flavor model and grep-safe tables;
house exemplars cited to real files.

## The law: stdout = payload, stderr = everything else

stdout carries the primary, machine-consumable output — what gets piped. stderr
carries messaging: progress, diagnostics, warnings, errors, narration, footers.
Never progress noise on stdout; never data on stderr (clig + Heroku, hard law).

House exemplars:

- `gif-mosaic` prints the output PNG *path* to stdout; "N frames in CxR grid"
  goes to stderr. `$(gif-mosaic in.gif)` composes.
- `memo` passes the wrapped command's stdout through untouched; its
  `[memo: hit/miss]` footer is stderr, tunable via `--footer=stdout|stderr|none`.
- `electron-apps --json | jaq …` stays clean because counts and caveat footnotes
  are stderr.
- **Hazel/launchd invokers**: Hazel treats stdout as failure text — routine
  narration goes to stderr and stdout stays *empty* unless there's a result
  (image-sort, heic-ai-rename precedent).

Heroku's refinement — two command flavors: **output commands** (display data)
print plainly to stdout; **action commands** (remote/long-running) narrate
progress on stderr with a tty-gated spinner and a plain fallback off-tty.

## tty detection, per stream

Detect whether stdout and stderr are ttys **independently** — `cmd | less` leaves
stderr interactive; `cmd 2>log` leaves stdout interactive. Human formatting,
color, spinners, and pagers all key off the *relevant* stream's ttyness.

## Machine escape hatches

- **`--json`** (full tier): full-fidelity structured output — everything the
  human view truncated to fit a terminal. Offered in addition to the human
  table, which stays the default ("support both grep and jq without sacrificing
  beautiful UX" — Heroku); when `--json` is passed, stdout carries exclusively
  valid JSON, diagnostics stay on stderr.
- **`--plain`** (clig): when human formatting breaks parseability, a stable
  one-record-per-line tabular format.
- `tokens` precedent: the default output IS machine-friendly (a bare integer);
  `--format json` adds structure. When the payload is trivially simple, plain
  stdout is already the machine format.

## Tables

- **Grep-safe flat tables**: one row per item, every row self-contained, category
  as a *column value* on each row. Heroku's counterexample: grouped sections
  under `====` headers put the category only in the header, so
  `grep "Common Runtime"` finds nothing. Flat rows make `grep tokyo` just work.
- House format (`emitTable`, `scripts/macos/electron_apps.nim:179-191`):
  left-aligned name column sized to the longest entry, fixed-width value columns,
  CAPS header row.
- Use a real column-alignment routine, not hand-spaced strings.

## Color

- 2–3 colors max; dim/bold/underline for further contrast rather than more hues
  (Heroku).
- **Red and yellow are reserved for errors and warnings** — nothing else gets
  them.
- Disable when: stream isn't a tty, `NO_COLOR` set (any non-empty value),
  `TERM=dumb`, or `--no-color` passed. All paths required; check per stream.
- Emoji/symbols in moderation; no raw escape codes when piped.

## Progress and verbosity

- Spinners/progress bars only on an interactive tty, always on stderr; plain
  line-based fallback otherwise (CI logs must not fill with `\r` garbage).
- A stalled progress bar must not read as a crash — keep it moving or say what's
  happening.
- Parallel output: hidden logs behind a progress display **must** surface fully
  on failure.
- Prefer *some* success output over total silence; provide `-q/--quiet` for
  scripting rather than forcing `2>/dev/null`.
- **No developer debug output by default** — gate it behind `-d/--debug` or `-v`.
- **stderr is not a log file**: no `ERR`/`WARN` level labels outside verbose mode.

## Conversation patterns (clig)

- **State-changing commands say what changed** — the `git push` model: report the
  action taken, not just exit 0.
- **Make current state inspectable and suggest next commands** — the `git status`
  model. After an action, name the likely follow-up.
- **Footers as parseable recovery hints** (house): memo's stderr footer contains
  the exact command to recover full output (`memo show -- cargo test`). A hint
  the user can copy-paste beats a hint they must reconstruct.
- Crossing the program's boundary (touching files not passed as args, network
  calls) is stated, not silent.

## Paging

Long output pages through `less -FIRX` — only when stdout is an interactive tty
(`-F` quits if it fits on one screen, so short output is unaffected).

## Checklist (for audits)

- [ ] Run it piped: stdout carries only payload; stderr carries the rest
- [ ] Hazel/launchd-invoked: stdout empty on routine runs
- [ ] `--json` present (full tier) and round-trips through `jaq` cleanly
- [ ] Tables flat and grep-safe; category on every row; CAPS header
- [ ] Color: `NO_COLOR`, `--no-color`, `TERM=dumb`, off-tty all disable it
- [ ] Red/yellow appear only on errors/warnings
- [ ] Spinners tty-gated, on stderr, with a non-tty fallback
- [ ] `-q` exists (full tier); no debug output by default
- [ ] State changes are reported; recovery hints are copy-pasteable
