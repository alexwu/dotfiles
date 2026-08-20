# Peekaboo verification patterns (field-tested)

Deep patterns for *proving* a macOS GUI behaves, distilled from real driving sessions. Load when a basic capture/click is not enough — flaky results, blank captures, or a need to prove *which* input path fired.

## Functional-accept verification (prefer over pixels)

Screenshots are a weak oracle: full-screen captures are too low-res to read small UI, and window capture blanks on glass (below). The strong signal is to **drive, then read a functional result**:

- **stdout** — for a CLI/app that prints on accept: fire the action, read the process's stdout.
- **clipboard sentinel** — for a "copy" action: `printf SENTINEL | pbcopy` *first*, fire the action, then `pbpaste`. A real payload = it worked; the sentinel surviving = nothing happened / it was cancelled.
- **structured logs** — for an app that emits OSLog events: stream them (next section) and assert on a known line.

Driving and observing are independent: synthetic input reaches the app no matter which capture mode (or none) is used. So drive to a known state, then assert on the result — not the rendered frame.

## Log-stream verification, and the `.info`-not-persisted trap

To verify via an app's own logs, **start the stream before the action** — `OSLog` `.info`/`.debug` levels are NOT persisted to the unified-log store, so a post-hoc `log show` will not retrieve them:

```bash
# Start streaming FIRST, in the background or another pane:
log stream --info --debug --style compact \
  --predicate 'subsystem == "com.example.app"'
# ...then fire the Peekaboo action. The line you want scrolls by live.
```

Tee to a file if you need to grep afterward. A cheap "did it populate?" probe is often a single log line the app already emits (e.g. an item-count or selection-id field) — cheaper and more reliable than reading pixels.

## Capture-mode selection & the glass-panel blank

```bash
peekaboo image --mode screen                    # full display — always composites
peekaboo image --mode area --region "x,y,w,h"   # scoped rect — reliable when you know the frame
peekaboo image --app X --mode window            # window-isolated — blanks on glass (see below)
```

**Window-isolated capture returns a blank (~20KB) PNG for borderless, non-activating, `.glassEffect` panels** — Spotlight/Raycast-style overlays, HUDs, anything with `isOpaque=false` + a clear background at `.floating` level. Window capture has no backdrop to composite the translucent material against, so it comes out empty on every capture engine. This is macOS compositing behavior, not a Peekaboo bug, and not a wrong PID.

For such panels:
- prefer `--mode area` driven off the panel's **real on-screen frame** (read it from the app's own layout log if it emits one — window-list bounds are often unreliable for borderless panels), or
- prefer `--mode screen`, or
- skip pixels and use functional-accept verification instead.

## Input-path testing: UIAX vs synthetic

Peekaboo can drive a target two ways, and proving *which* one works is often the point of a verification:

- **UIAX / action path** — accessibility actions (`AXPress`, `AXSetValue`).
- **Synthetic path** — CG/CA pointer & keyboard events.

```bash
# Capture a snapshot to pin elements:
peekaboo see --app Calculator --json > /tmp/see.json   # read snapshot_id + elem ids with jaq

# UIAX/action click only (proves live AX re-resolution + action invocation):
peekaboo click --on elem_8 --snapshot "$SNAP" --input-strategy actionOnly --json --no-auto-focus

# Cleanest pure UIAX smoke test — invoke the AX action directly:
peekaboo perform-action --on elem_8 --action AXPress --snapshot "$SNAP" --json

# Synthetic click only (proves coordinate resolution + event delivery):
peekaboo click --on elem_20 --snapshot "$SNAP" --input-strategy synthOnly --json

# Negative control — coordinates cannot use actionOnly:
peekaboo click --coords 10,10 --input-strategy actionOnly --json --no-auto-focus
```

Interpretation:
- `actionOnly` success ⇒ accessibility resolution + action invocation work.
- `synthOnly` success ⇒ coordinate resolution + event delivery work, **but verify app state independently** (a synthetic click can be swallowed by an unfocused app — `--no-auto-focus` proves background behavior, or fails because focus was required).
- A snapshot-backed UIAX action must target the **captured** app/window, not the frontmost one. If it resolves in the wrong app, suspect snapshot `windowContext` preservation.

`Calculator` is a good fixture: it exposes element identifiers (`One`, `Two`, `Add`, `Equals`, `StandardInputView`) and descriptions, so you can assert against known IDs.

## Clean slate before a repro

Duplicate or stale instances silently confound results — a leftover process may answer or hold a socket while you think you are driving a fresh one:

```bash
pkill -KILL <ProcessName>
pgrep <ProcessName>          # confirm empty before launching one fresh instance
```

A `gtimeout N <app>` that keeps a UI open until killed exits **124** — that is the timeout firing, not a failure. Treat "worked yesterday, blank today" as a stale-process or revoked-TCC-grant problem first, before chasing a code regression.

## Deterministic multi-step flows with `.peekaboo.json`

Synthetic event chains race async UI (reloads, animations, navigation pushes); a `type` then immediate `press return` can fire before the list repopulates. Options, in order of robustness:

1. Single-step assertion where possible.
2. `peekaboo sleep <ms>` or a re-`see` between steps to resynchronize.
3. A `.peekaboo.json` script run via `peekaboo run` — encodes the sequence with built-in waits and `--no-fail-fast` control, more reliable than shelling out N separate synthetic commands.

## Permission posture

Peekaboo does not enforce a per-app allowlist itself — scoping which apps it may drive has to come from the harness (Claude Code permissions allowlisting specific `peekaboo` subcommands, denying broad `screencapture`). Until that is configured, treat `peekaboo` invocations as needing explicit user authorization for the target app.
