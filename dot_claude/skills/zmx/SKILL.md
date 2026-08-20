---
name: zmx
description: >-
  Use zmx, a terminal session-persistence CLI — named, detachable sessions that
  survive terminal and SSH disconnects (the keep-the-process-alive half of tmux,
  without windows, tabs, or panes). Use this skill whenever zmx is mentioned, or
  whenever the user wants to: run a command in a persistent or background
  terminal session, keep a long-running process alive after closing the
  terminal, attach/detach/list/kill named sessions, tail or follow a session's
  live output, wait on a backgrounded command, send keystrokes to an interactive
  program running in a session, write a file into a session over SSH, label
  sessions with key=value metadata, or set up zmx shell integration (prompt
  indicator, completions, fzf session picker, SSH config). Covers every zmx
  subcommand with v0.6.0 flag semantics, what v0.7.0 changed (labels, XDG log
  paths, bash-only `run`, ANSI-stripped output), and the behavior gotchas the
  README glosses over — including two commands its own help advertises but the
  binary lacks.
---

# zmx — terminal session persistence

`zmx` keeps terminal processes alive independently of the terminal that started
them. Attach, detach, and re-attach to a named session without killing what's
running inside it; run commands in a session without attaching at all;
reconnect after an SSH drop and find your scrollback intact.

It deliberately does **not** do windows, tabs, or splits — that is your OS
window manager's job. Mentally: `zmx` is the "persist the session" half of
`tmux`/`screen`, and nothing else.

## Mental model

- **One daemon per session.** Each session is its own background process with
  its own Unix socket. There is no central server.
- **A session wraps one PTY** running a shell (or a command you supply).
  Closing your terminal does not end the session.
- **Multiple clients** can attach to the same session at once.
- **State is restored on re-attach** via libghostty-vt — scrollback and screen
  contents come back as if you never left.

## Install

```sh
brew install neurosnap/tap/zmx
```

Homebrew also installs shell completions. Other routes: prebuilt binaries from
`https://zmx.sh/a/`, distro packages (AUR, Alpine, openSUSE, Gentoo), or
`zig build -Doptimize=ReleaseSafe --prefix ~/.local` from source (needs Zig
v0.15). Completion, prompt, and SSH setup live in `references/integration.md`.

## Commands

Running `zmx` with no arguments is `zmx list`. Most commands have a short alias.

| Command | Alias | Purpose |
|---|---|---|
| `attach <name> [cmd...]` | `a` | Attach to a session, creating it if it doesn't exist |
| `run <name> [-d] [cmd...]` | `r` | Run a command in a session without attaching |
| `send <name> <text...>` | `s` | Send raw bytes to the session's shell input |
| `print <name> <text...>` | `p` | Inject text into the session's display/scrollback only |
| `write <name> <path>` | `wr` | Pipe stdin to a file *inside* the session (works over SSH) |
| `detach` | `d` | Detach every client from the current session |
| `list [--short]` | `l`, `ls` | List active sessions |
| `kill <name>... [--force]` | `k` | Kill one or more sessions |
| `history [<name>] [--vt\|--html]` | `hi` | Print a session's scrollback |
| `wait <name>...` | `w` | Block until a session's `run` tasks finish |
| `tail <name>...` | `t` | Follow a session's output live |
| `set <name> k=v...` | — | **0.7.0+** Attach labels; `k=` removes one |
| `get <name> [key]` | `g` | **0.7.0+** Read labels (all, or one value) |
| `clear <name>` | — | **0.7.0+** Remove every label |
| `completions <shell>` | `c` | Emit a completion script (`bash`/`zsh`/`fish`, `nu` on 0.7.0+) |
| `version` | `v` | Version + socket/log directory paths |
| `help` | `h` | Help text |

Full flag-by-flag detail, exit codes, and per-command gotchas:
**`references/commands.md`**.

> **Two commands in upstream's help do not exist.** `zmx list --where k=v` is
> advertised in the compiled help but the dispatcher only parses `--short`, so
> the flag is swallowed and you get *every* session. `zmx unset` appears in the
> README's help block but has no branch in the binary at all. Filter labels with
> `rg`; remove one with `zmx set <name> key=`. Verified against `src/main.zig`
> at the `v0.7.0` tag.

## attach vs run vs send vs print

These four all "put something into a session" but are not interchangeable —
picking the wrong one is the most common zmx mistake.

- **`attach`** — *you* take over the session interactively. Spawns/connects a
  login shell on a PTY. This is for humans.
- **`run`** — execute a command and get its result. Synchronous: it blocks,
  streams output, and exits with the command's exit code. This is the command
  for scripted/automated execution.
- **`send`** — raw keystrokes into the shell's input. No exit tracking, no
  auto-newline. For driving interactive programs (a TUI, a REPL, a confirmation
  prompt) or sending control characters.
- **`print`** — text painted onto the session's screen and scrollback. The
  shell never sees it. For annotating a session a human is watching.

## Behavior that bites

These are real, and the README is quiet about some of them.

- **`run` is synchronous** (since v0.5.0). `zmx run dev zig build` blocks until
  the build finishes and exits with the build's exit code. For fire-and-forget,
  add `-d` and track it with `wait`. Any "run is async" advice predates v0.5.0.
- **`run` needs a `$?`-capable shell.** It detects the command's exit code via
  a shell marker. On **0.7.0+** a session created by `run` always spawns
  `/bin/bash` regardless of `$SHELL`, which makes `--fish` vestigial there. On
  **0.6.0** the login shell is used, so pass `--fish` when it's fish
  (`zmx run dev --fish ls src`).
- **Streamed output is plain text on 0.7.0+.** ANSI escapes are stripped from
  the shared streaming path — which is `zmx tail` *and* synchronous `zmx run`,
  not just `tail` as the changelog says. Colors, prompts, and cursor moves no
  longer reach your stdout. Good for scripting; don't expect color back.
- **`run` commands are sequential and non-interactive.** Don't fire two `run`s
  at the same session in parallel. Don't `run` a pager/editor/prompt — it hangs
  the session. Pass the command unquoted (`zmx run dev grep -r TODO src`, not
  `zmx run dev "grep -r TODO src"`); zmx re-quotes metacharacters itself.
- **`kill` and `wait` wildcards need an explicit `*`** (since v0.5.0):
  `zmx kill "d.*"` kills every `d.`-prefixed session, `zmx kill "*"` kills all.
  A bare name is an exact match.
- **`detach` vs `ctrl+\`.** `zmx detach` disconnects *all* clients from the
  session. The `ctrl+\` keystroke disconnects only *your* client. Closing the
  terminal window also detaches.
- **`send` appends no newline.** `zmx send dev ls` types `ls` and leaves the
  cursor there. Append `\r` to execute: `printf 'ls\r' | zmx send dev`.
- **`history` defaults to the current session.** With no `<name>` it uses
  `$ZMX_SESSION` — convenient from inside a session, an error from outside one.
- **`ZMX_SESSION_PREFIX` rewrites every name.** If set, every command's session
  name is silently prefixed. Sessions "missing" from `list` are often just
  living under a prefix.
- **Logs moved in 0.7.0.** They were `{socket_dir}/logs/`; they are now
  `$XDG_STATE_HOME/zmx/logs`, falling back to `~/.local/state/zmx/logs`. Read
  the path off `zmx version` rather than assuming either.
- **Upgrading 0.6.0 → 0.7.0 does not kill running sessions, but it half-breaks
  them.** Daemons keep running (they hold their own inode) and the wire protocol
  was built for it — `ipc.Tag` is non-exhaustive with a comptime-enforced `_`
  arm, new tags were appended, and `Info` is frozen. But a 0.7.0 *client* driving
  a 0.6.0 *daemon* has two silent failures: **`zmx send` does nothing** (it moved
  from tag `.Input` to a new `.Send`, which the old daemon logs and drops, still
  exiting 0), and **resizes are dropped** (`Resize` grew 4→8 bytes and the old
  handler early-returns on a size mismatch). Recreate any session you need to
  `send` into or resize. Full matrix in `references/commands.md`.

## Workflows

### Run a command, get its output and exit code

```sh
zmx run build zig build        # blocks; exits with the build's code
```

`run` creates the `build` session if needed and reuses it for later `run`s.

### Background a long task and wait for it

```sh
zmx run -d ci ./long-test-suite.sh   # returns immediately
# ... do other work ...
zmx wait ci                          # blocks until done; exits non-zero on failure
```

On failure, `wait` prints the last 20 lines of each failed task automatically.

### Watch a session's output live

```sh
zmx tail dev          # follows until the session closes; read-only
```

### Find and filter sessions

`zmx list` has no JSON mode, but its output is line-oriented `key=value`
(tab-separated), which `rg` / `cut` / `awk` parse cleanly:

```sh
zmx list | rg 'clients=0\b' | rg -o 'name=[^\t]+' | cut -d= -f2-   # detached session names
```

Field extraction, filtering by directory or client count, feeding name lists
into `kill` / `wait` / `tail`, a readable table, and timestamp conversion are
all in `references/recipes.md`.

### Tag sessions with labels (0.7.0+)

Labels are in-memory `key=value` metadata scoped to the session's lifetime —
they die with the daemon and are not persisted anywhere.

```sh
zmx set ci project=zmx stage=build     # attach labels
zmx set . status=fail                  # "." is the current session
zmx get ci                             # all labels: "project=zmx stage=build"
zmx get ci project                     # one value: "zmx"
zmx set ci stage=                      # empty value removes that label
zmx clear ci                           # remove all
zmx list | rg 'stage=build'            # filter (there is no --where; see above)
```

Keys and values accept **only** alphanumerics plus `-`, `_`, and `.` — no
spaces, `:`, or `/`. `name`, `start_dir`, and `cmd` are reserved and rejected.
`zmx list` appends each label as a trailing tab-separated field.

### Drive an interactive program

```sh
zmx send repl "$(printf 'print(1+1)\r')"   # type into a REPL and run it
zmx send dev "$(printf '\x03')"            # send Ctrl-C
```

### Inspect scrollback / debug a hang

`zmx history <session>` dumps the full scrollback. The zmx docs suggest piping
it through `tail` — don't: piping to `tail` discards everything above the cut.
Use `memo`, which truncates the *display* but keeps the full output one command
away:

```sh
memo --tail 100 -- zmx history dev
memo show -- zmx history dev          # full scrollback, no re-run
```

**Snapshot caveat:** `memo` caches by command for ~5 minutes. If the session is
still producing output, a repeated `memo --tail 100 -- zmx history dev` returns
the *cached* snapshot, not the current state. When you need the live picture:

- `memo invalidate --now -- zmx history dev` — re-run and refresh the cache, or
- `zmx tail dev` — follow the output live (zmx's own `tail -f` equivalent).

If a `zmx run` hangs: recover with `zmx send <session> "$(printf '\x03')"`
(Ctrl-C), then inspect via `memo --tail 100 -- zmx history <session>` or watch
live with `zmx tail <session>`.

### Write a file into a session (including over SSH)

```sh
cat config.toml | zmx write dev ~/app/config.toml
```

zmx base64-encodes and chunks the data through the PTY; the far end needs
`base64` and `printf`. The path must not contain single quotes.

## Reference files

- **`references/commands.md`** — every subcommand: all flags, defaults, exit
  codes, examples, and per-command gotchas; the label commands; and the full
  0.6.0↔0.7.0 client/daemon compatibility matrix. **Load when** you need exact
  flag semantics, or before upgrading zmx with sessions still running.
- **`references/recipes.md`** — parsing and filtering `zmx list` / `zmx version`
  output without a JSON mode: field extraction, filtering by client count,
  directory, or label, feeding name lists into `kill` / `wait`, a readable
  table, and timestamp conversion.
- **`references/integration.md`** — shell prompt indicator (fish / bash / zsh /
  powerlevel10k / oh-my-posh / Starship), completion setup, the fzf session
  picker, the SSH multi-window workflow, `ZMX_SESSION_PREFIX`, socket-directory
  resolution, permissions, and log paths.
