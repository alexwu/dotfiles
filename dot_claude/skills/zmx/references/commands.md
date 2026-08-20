# zmx command reference

Ground truth as of zmx **v0.6.0**. Anything marked **0.7.0+** was verified
against `src/*.zig` at the `v0.7.0` tag and is *not* present in 0.6.0. Check
which one you're on with `zmx version`.

## Contents

- [Session names](#session-names)
- [attach](#attach--a) · [run](#run--r) · [send](#send--s) · [print](#print--p)
  · [write](#write--wr)
- [detach](#detach--d) · [list](#list--l--ls) · [kill](#kill--k)
- [history](#history--hi) · [wait](#wait--w) · [tail](#tail--t)
- [set](#set-070) · [get](#get--g-070) · [clear](#clear-070)
- [completions](#completions--c) · [version](#version--v) · [help](#help--h)
- [Environment variables](#environment-variables)
- [Upgrading 0.6.0 → 0.7.0](#upgrading-060--070)

## Session names

Every command that takes `<name>` resolves it the same way:

- If `ZMX_SESSION_PREFIX` is set, it is prepended: effective name =
  `prefix + name`.
- Names cannot contain `/`, null bytes, or be exactly `.` or `..` — they become
  Unix socket filenames.
- Maximum length is bounded by the socket path limit (roughly 100 characters
  minus the socket directory path).
- `kill` and `wait` accept a trailing `*` for prefix matching (see each).

## attach / a

```
zmx attach <name> [command...]
```

Attach to session `<name>`, creating it first if it does not exist (an
"upsert"). Spawns a login `$SHELL` on a PTY; an optional `command` runs in place
of the shell.

- If `command` is given but the session already exists, the command is ignored
  (logged as a warning).
- **From inside a zmx session** (`$ZMX_SESSION` is set), `attach <other>` does
  not nest — it *switches* the current client to `<other>`.
- Detach without killing the session: close the terminal window, press
  `ctrl+\` (this client only), or run `zmx detach` (all clients).

```sh
zmx attach dev                              # attach to / create "dev", login shell
zmx attach logs tail -f /var/log/system.log # session runs a command instead of a shell
```

## run / r

```
zmx run <name> [-d] [--fish] [command...]
```

Run `command` in session `<name>` without attaching. Creates the session if
needed.

- **Synchronous by default** (since v0.5.0): blocks, streams the command's
  output to your stdout, and exits with the command's exit code.
- `-d` — detached: send the command and return immediately (prints
  `command sent!`). Track completion with `zmx wait`.
- `--fish` — declare the session's shell is fish, required there for exit-code
  tracking. **0.7.0+**: a session *created by* `run` always spawns `/bin/bash`
  regardless of `$SHELL`, so `--fish` only matters when `run` targets a session
  someone else created with a fish login shell. Upstream's rationale: tracking
  exit status across shells had too many edge cases to keep `run` useful.
- **0.7.0+ strips ANSI escapes from the streamed output.** The changelog
  attributes this to `zmx tail`, but `tail()` is the shared streaming path and
  `is_run_cmd` routes through it — so synchronous `run` output is plain text
  too. Prompts, colors, and cursor movement no longer corrupt the caller's
  terminal.
- **0.7.0+ detects heredocs** and places the completion marker on its own line,
  so `zmx run dev 'cat <<EOF ... EOF'` no longer swallows the exit code.
- If no `command` arguments are given, the command is read from stdin.
- Pass the command **as-is — do not quote-wrap it**. zmx re-quotes shell
  metacharacters itself.
- Commands run **sequentially** per session; a second `run` resets and reuses
  the same shell. Do not run parallel `run`s against one session.
- **Interactive programs hang it** — no pagers, editors, or prompts. Disable
  pagers explicitly (`git -c core.pager=cat ...`, `--no-pager`, `| cat`).

```sh
zmx run dev ls src
zmx run dev zig build
zmx run dev grep -r TODO src
zmx run dev git -c core.pager=cat diff
zmx run dev --fish ls src          # session shell is fish
zmx run -d dev sleep 30            # detached; pair with: zmx wait dev
echo 'make test' | zmx run dev     # command from stdin
```

## send / s

```
zmx send <name> <text...>
```

Send raw bytes to the session's PTY input (the shell's stdin). The session must
already exist — `send` does not create sessions.

- Fire-and-forget: no completion marker, no exit-code tracking (unlike `run`).
- **No carriage return is appended.** Include `\r` yourself to execute a
  command.
- Text comes from arguments or piped stdin. From stdin, a trailing `\n` is
  stripped.

Use it for programs that read stdin directly — TUIs, REPLs, prompts — and for
sending control characters.

```sh
printf 'echo hello\r' | zmx send dev      # type a command AND run it
zmx send dev "$(printf '\x03')"           # send Ctrl-C
zmx send claude /compact                  # type text, no newline (no \r)
```

## print / p

```
zmx print <name> <text...>
```

Inject text directly into the session's display and scrollback. The shell/PTY
never sees it — this is purely visual. The session must already exist.

- You control all newlines; terminals expect `\r\n`.

```sh
printf '\r\n=== deploy starting ===\r\n' | zmx print dev
```

## write / wr

```
zmx write <name> <file_path>
```

Pipe stdin to `file_path` *inside* the session. Creates the session if needed.

- `file_path` is absolute or relative to the session shell's working directory.
- Works over SSH — data is base64-encoded and chunked (~48 KB per chunk) through
  the PTY. The far end needs `base64` and `printf`.
- The path **must not contain single quotes**.

```sh
echo "hello" | zmx write dev /tmp/hello.txt
cat main.zig | zmx write dev src/main.zig
```

## detach / d

```
zmx detach
```

Detach **every** client from the current session (read from `$ZMX_SESSION`).
Errors if not run from inside a session.

- To detach only your own client, press `ctrl+\` instead.

## list / l / ls

```
zmx list [--short]
```

List active sessions. Running `zmx` with no arguments does this.

- `--short` — name only, one per line; also stays silent (no "no sessions found"
  line) when there are no sessions.
- With no sessions, the default form prints `no sessions found in <dir>` to
  **stderr**.
- Default output is one tab-separated `key=value` line per session. The current
  session's line is prefixed with `→ `, every other line with two spaces.
  Fields, in emission order — the first four always present, the rest
  conditional:

  | Field | When |
  |---|---|
  | `name` `pid` `clients` `created` | always (`clients` = attached count, `created` = epoch **seconds**) |
  | `start_dir` | session recorded a working directory |
  | `cmd` | session was created with an explicit command |
  | `ended` `exit_code` | a `run` task has finished in that session |
  | `<label>=<value>`… | **0.7.0+**, one field per label, key-sorted, appended last |

  A session whose daemon didn't answer emits a different shape entirely:
  `name=… err=<ErrorName> status=<cleaning up|unreachable>`.
- **`--where k=v` does not work.** The compiled help advertises
  `[l]ist|ls [--short|--where k=v]`, but the argument loop in `src/main.zig`
  only ever tests for `--short`, and `list()` takes no filter parameter — the
  flag and its argument are consumed and discarded, so you silently get every
  session. zmx's own Labels help corroborates this by suggesting
  `zmx list | grep project=zmx`. Filter with `rg` (see `recipes.md`).
- Parsing and filtering this output (no JSON mode): see `recipes.md`.

## kill / k

```
zmx kill <name>... [--force]
```

Kill one or more sessions and disconnect their clients.

- Accepts multiple names.
- A trailing `*` makes a name a **prefix match**: `zmx kill "d.*"` kills every
  `d.`-prefixed session; `zmx kill "*"` kills all.
- `--force` — if a session's daemon is unresponsive, clean up its stale socket
  file instead of skipping it with an error.
- Kill sequence: SIGHUP to the process group, a 500 ms grace period, then
  SIGKILL.

```sh
zmx kill dev
zmx kill dev test logs
zmx kill "d.*"
```

## history / hi

```
zmx history [<name>] [--vt|--html]
```

Print session `<name>`'s scrollback.

- `<name>` is optional — it defaults to `$ZMX_SESSION` (the current session).
  Outside a session with no name given, this errors.
- `--vt` — include raw VT/ANSI escape sequences.
- `--html` — render as HTML.
- default — plain text.

To view only the tail end, **do not pipe to `tail`** — that discards everything
above the cut. Use `memo`, which truncates the display but keeps the full
output retrievable:

```sh
memo --tail 100 -- zmx history dev
memo show -- zmx history dev          # full scrollback, no re-run
```

For a session that is still producing output, `memo`'s cached snapshot can go
stale within its ~5-minute TTL. Refresh it with
`memo invalidate --now -- zmx history dev`, or follow the session live with
`zmx tail dev`.

## wait / w

```
zmx wait <name>...
```

Block until the `run` tasks in the named session(s) complete. Pair with
`zmx run -d`.

- Accepts multiple names and the same trailing-`*` prefix matching as `kill`.
- With `ZMX_SESSION_PREFIX` set and **no name given**, waits on every session
  under that prefix.
- On task failure, prints the last 20 lines of each failed session's scrollback.
- Exit codes: `0` — all tasks succeeded; the last failing task's exit code on
  failure; `2` — no matching sessions appeared (gives up after 3 polls); `1` —
  a tracked session vanished before completing.

```sh
zmx run -d ci ./suite.sh
zmx wait ci
zmx wait "ci.*"        # all ci.-prefixed sessions
```

## tail / t

```
zmx tail <name>...
```

Follow the named session(s)' output live, read-only — zmx's native equivalent
of `tail -f`. Streams until the session closes. Accepts multiple names and
trailing-`*` prefix matching.

```sh
zmx tail dev
zmx tail "d.*"
```

**0.7.0+ strips ANSI escapes** from this stream, so what you get is plain text —
no colors, prompt sequences, or cursor movement leaking into your terminal.
Same code path as synchronous `run`, so that output is plain now too. On 0.6.0
both still carry raw VT sequences.

## Labels (0.7.0+)

Three commands attach `key=value` metadata to a **live** session. Labels are
held in the daemon's memory, scoped to the session's lifetime — nothing is
persisted, and killing the session drops them.

**Shared rules for all three:**

- The session must already exist; these do not create sessions.
- `<name>` may be `.`, which resolves to `$ZMX_SESSION`. Outside a session that
  errors with `"." requires ZMX_SESSION (are you inside a zmx session?)`.
- `ZMX_SESSION_PREFIX` applies, same as every other command.
- Keys and values accept **only** `[A-Za-z0-9]`, `-`, `_`, and `.`. A space,
  `:`, or `/` is rejected — which also means values cannot hold a path.
- `name`, `start_dir`, and `cmd` are **reserved keys** and rejected. Nothing
  else is: `zmx set dev clients=0` is legal and will inject a second
  `clients=0` field into that session's `zmx list` line (see `recipes.md`).
- Against a 0.6.0 daemon these fail cleanly with
  `error: session "X" does not support labels (daemon too old?)`.

### set (0.7.0+)

```
zmx set <name> <k=v>...
```

Attach or overwrite labels. **No short alias** — `zmx s` is `send`.

- An **empty value removes** that key: `zmx set dev project=`.
- Multiple pairs in one call; unrecognized-shaped args are parsed by the same
  space-separated `k=v` iterator, so quote nothing.

```sh
zmx set ci project=zmx stage=build
zmx set . status=fail              # label the current session
zmx set ci stage=                  # remove just "stage"
zmx set next "$(zmx get prev)"     # copy every label off another session
```

### get / g (0.7.0+)

```
zmx get <name> [key]
```

Print labels to stdout. With no `key`, prints all of them as one
space-separated `k=v k=v` string, **key-sorted and with no trailing newline** —
which is what makes the `zmx set next "$(zmx get prev)"` round-trip work. With
a `key`, prints just that value; a missing key is a `LabelKeyNotFound` error.

```sh
zmx get ci             # project=zmx stage=build
zmx get ci project     # zmx
```

### clear (0.7.0+)

```
zmx clear <name>
```

Remove every label from the session. **The `cl` alias does not work** — the
help text prints `[cl]ear`, but the dispatcher only matches the literal string
`clear`. Spell it out.

> `zmx unset` does not exist. The README's help block lists
> `[un]set <name> key ...`, but there is no such branch in the binary. Remove a
> label with `zmx set <name> key=`.

## completions / c

```
zmx completions <bash|zsh|fish|nu>
```

Emit a shell completion script to stdout. An unknown shell name exits silently.
`nu` (nushell) is **0.7.0+**; 0.6.0 accepts only `bash`, `zsh`, and `fish`.
Wiring it into each shell is covered in `integration.md`.

## version / v

```
zmx version          # also: zmx -v, zmx --version
```

Prints the zmx version, the bundled `ghostty-vt` version, and the resolved
socket and log directory paths — useful for confirming where sessions and logs
actually live.

## help / h

```
zmx help             # also: zmx -h
```

Every subcommand also accepts `--help` / `-h`, which currently prints this same
global help text rather than command-specific help.

## Environment variables

| Variable | Effect | Default |
|---|---|---|
| `SHELL` | Shell launched for new interactive sessions | system shell |
| `ZMX_DIR` | Socket directory — priority 1 | — |
| `XDG_RUNTIME_DIR` | Socket directory — priority 2 (`/zmx` appended) | — |
| `TMPDIR` | Socket directory — priority 3 (`/zmx-<uid>` appended) | `/tmp` |
| `ZMX_SESSION` | Current session name; injected into the session automatically | — |
| `ZMX_SESSION_PREFIX` | Prefix prepended to every session name in every command | empty |
| `ZMX_DIR_MODE` | Octal mode for socket and log directories | `0750` |
| `ZMX_LOG_MODE` | Octal mode for log files | `0640` |
| `XDG_STATE_HOME` | **0.7.0+** Log directory — priority 2 (`/zmx/logs` appended) | — |
| `HOME` | **0.7.0+** Log directory — priority 3 (`~/.local/state/zmx/logs`) | — |

Socket directory resolution order and log file paths are detailed in
`integration.md`.

## Upgrading 0.6.0 → 0.7.0

Replacing the binary (`brew upgrade zmx`) **does not kill running sessions** —
each daemon is an already-exec'd process holding its own inode. The wire
protocol is explicitly designed for a version skew: `ipc.Tag` is non-exhaustive
with a comptime-enforced `_` arm (*"old daemons rely on `_` to ignore unknown
tags"*), 0.7.0's new tags were **appended** at 14–18 rather than inserted, and
the `Info` struct is marked frozen and is byte-identical between the two tags.
A 0.6.0 daemon receiving an unknown tag logs `ignoring unknown IPC tag=N` and
carries on.

What it *does* do is half-break every session created before the upgrade, once
you drive it with a 0.7.0 client:

| Command | 0.7.0 client → 0.6.0 daemon |
|---|---|
| `send` | **Silently does nothing.** Moved from tag `.Input`(1) to a new `.Send`(18) so it would stop claiming client leadership; the old daemon drops tag 18 — and `zmx send` still exits `0`. |
| `attach` | Connects and renders, but **resize is silently dropped**. `Resize` grew from `{rows, cols}` to `{rows, cols, xpixel, ypixel}` (4→8 bytes) and 0.6.0's `handleResize` opens with `if (payload.len != @sizeOf(ipc.Resize)) return;`. Attach from a different-sized window and the display stays wrong. |
| `set` / `get` / `clear` | Clean, loud error — `does not support labels (daemon too old?)`. |
| `list` | Works; no labels shown; **~50 ms slower per stale session** — the probe now sends `LabelGet` alongside `Info` and waits out a 50 ms poll for a `LabelData` reply that never arrives. |
| `run` `history` `kill` `wait` `write` `detach` | Unchanged tags and payloads — unaffected. |

Clients **already attached** are still 0.6.0 processes and keep working
normally; only newly-invoked clients are 0.7.0.

Practical upgrade path: treat pre-upgrade daemons as read-mostly — `run`,
`history`, `wait`, and `kill` against them are fine — and recreate any session
you need to `send` into or resize. The `send` case is the dangerous one,
because it fails successfully.
