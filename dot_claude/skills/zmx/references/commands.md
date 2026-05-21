# zmx command reference

Ground truth as of zmx **v0.6.0**. Notes flagged "newer builds" reflect changes
staged after the v0.6.0 release.

## Contents

- [Session names](#session-names)
- [attach](#attach--a) · [run](#run--r) · [send](#send--s) · [print](#print--p)
  · [write](#write--wr)
- [detach](#detach--d) · [list](#list--l--ls) · [kill](#kill--k)
- [history](#history--hi) · [wait](#wait--w) · [tail](#tail--t)
- [completions](#completions--c) · [version](#version--v) · [help](#help--h)
- [Environment variables](#environment-variables)

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
  tracking. Newer builds run `run` commands under `/bin/bash` regardless of the
  login shell, so the session shell must support `$?`.
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

- `--short` — terser output; also stays silent (no "no sessions found" line)
  when there are no sessions.
- With no sessions, the default form prints `no sessions found in <dir>` to
  **stderr**.
- Default output is one tab-separated line per session with `name`, `pid`,
  `clients` (attached client count), `created` (Unix epoch seconds), and
  `start_dir`. The current session's line is prefixed with `→`.
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

## completions / c

```
zmx completions <bash|zsh|fish>
```

Emit a shell completion script to stdout. An unknown shell name exits silently.
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

Socket directory resolution order and log file paths are detailed in
`integration.md`.
