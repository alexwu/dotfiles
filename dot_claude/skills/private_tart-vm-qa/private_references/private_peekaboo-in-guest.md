# Driving a native app with peekaboo inside the tart guest

Everything runs over SSH (`sshpass -p admin ssh $SSH_OPTS admin@$IP '<cmd>'`); peekaboo inherits full
GUI-automation TCC from the sshd pre-grants. All commands below are the guest-side part of that SSH call.

## One-time provisioning (persists in the VM disk)

The guest ships Homebrew — install with it (verified working in-guest):

```bash
export PATH=/opt/homebrew/bin:$PATH
brew install steipete/tap/peekaboo
```

(Offline fallback: `scp "$(readlink -f /opt/homebrew/bin/peekaboo)"` from the host — readlink first, the brew path is a symlink scp won't resolve — then `sudo install` it to `/usr/local/bin`.)

Sanity check — all three must say Granted (they do, via sshd's TCC rows):

```bash
/opt/homebrew/bin/peekaboo permissions
```

Always the absolute path `/opt/homebrew/bin/peekaboo` — non-interactive SSH PATH doesn't include it.

## Drive loop (verified working)

```bash
/opt/homebrew/bin/peekaboo list apps                          # is the target running? bundle id + window count
/opt/homebrew/bin/peekaboo see --app <App> --path /tmp/see.png --json   # element ids + snapshot
/opt/homebrew/bin/peekaboo click --app <App> --coords 400,300 # focus a spot in the window
/opt/homebrew/bin/peekaboo type 'some text' --app <App>
/opt/homebrew/bin/peekaboo press return --app <App>
/opt/homebrew/bin/peekaboo image --mode screen --path /tmp/shot.png     # full-display capture
```

**Pin every input command with `--app <App>`.** A bare `peekaboo press return` completes in
milliseconds and silently goes nowhere — this exact failure ate the first smoke run. `--app` pinning
fixed it 100% of the time.

## Verify functionally, not just visually

For a terminal app, type a command whose side effect is checkable over SSH:

```bash
/opt/homebrew/bin/peekaboo type 'touch /tmp/qa-marker' --app <App>
/opt/homebrew/bin/peekaboo press return --app <App>
# then poll: test -f /tmp/qa-marker   (retry up to ~10s — keystroke → PTY → shell isn't instant)
```

The marker file proves keystrokes reached the app's PTY and the shell executed — a screenshot alone can't.

## Pulling artifacts to the host

```bash
scp admin@$IP:/tmp/shot.png ./dist/qa/
```

One remote file per scp call — multiple `host:path` args after sshpass fail silently on the second.

## Capture notes

- `--mode screen` is the reliable mode and renders everything (menu bar, Dock, windows) even fully headless.
- Window-scoped capture (`--mode window`) is unverified in the guest; a Tahoe-guest per-window
  compositor bug has been reported elsewhere (trycua/cua#912). If a window capture comes back
  blank, fall back to `--mode screen` — do not debug the app.
- Clean slate before a repro: `pkill -x <App>; sleep 1` then relaunch with `open -a`.
