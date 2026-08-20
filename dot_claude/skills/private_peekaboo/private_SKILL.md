---
name: peekaboo
description: This skill should be used when the user asks to "use peekaboo", "drive the app with peekaboo", "screenshot the app", "capture the UI", "click/type/press with peekaboo", "verify the UI", "inspect the accessibility tree", "automate a macOS app", or any macOS desktop GUI verification needing current UI state, synthetic input, or screen capture. Covers the see→interact→verify loop, capture modes, functional-accept verification, permissions, and the hard-won gotchas (blank capture on borderless/glass panels, press vs key, clean-slate before a repro).
allowed-tools: Bash(peekaboo:*), Bash(pgrep:*), Bash(pkill:*), Bash(log:*), Bash(pbpaste:*), Bash(pbcopy:*), Bash(osascript:*)
---

# Peekaboo — macOS GUI verification & automation

Peekaboo is a macOS CLI (`/opt/homebrew/bin/peekaboo`, v3.4.1+) that lets an agent capture the screen, read the live accessibility tree, and synthesize input — the tool for *verifying that a GUI change actually works in the real app*, not just in tests.

Command surfaces move fast across releases. Treat this skill as the durable workflow and the **live binary as the source of truth** for exact flags.

## Authoritative sources (check these before trusting any memorized flag)

- `peekaboo <command> --help` — exact flags for one command.
- `peekaboo learn` — the full agent guide (system prompt + tool catalog + signatures).
- `peekaboo tools` — the MCP/agent tool catalog.
- `peekaboo --version` — embedded build/commit metadata.

A condensed command catalog (stable categories, per-command one-liners) is in `references/command-map.md` — use it to discover *which* command, then `--help` for the flags.

## Step 0 — permissions and identity

Synthetic input and capture both require TCC grants. Before assuming a failure is a Peekaboo bug, confirm the grant:

```bash
peekaboo permissions status      # Screen Recording + Accessibility
peekaboo list apps --json        # is the target app even visible?
```

Peekaboo identifies an app by its **bundle display name**, not its process name. `peekaboo list apps` shows `DisplayName (com.bundle.id)`. If several processes share a display name, disambiguate with `--pid <pid>` (`pgrep` the process). `.accessory`/agent apps (no Dock icon) **are** visible to Peekaboo — it only drops `.prohibited`.

## The core loop: see → interact → verify

Modern Peekaboo is built around `see`, which captures the UI and returns stable element IDs + a snapshot ID. Prefer element IDs over raw coordinates:

```bash
# 1. SEE: capture fresh element IDs + snapshot id (recapture after any UI change)
peekaboo see --app Calculator --json > /tmp/see.json

# 2. INTERACT: act on a discovered element, pinned to the snapshot for stability
#    (read elem ids + snapshot_id out of the JSON with jaq, not by eye)
peekaboo click --on elem_8 --snapshot "<snapshot_id>" --json
peekaboo type "hello"
peekaboo press return

# 3. VERIFY: re-see and assert, or use a functional signal (below)
peekaboo inspect-ui --app Calculator        # AX-tree text without a screenshot
```

Rules of the loop:

- **Recapture with `see` after the UI changes** — stale element IDs resolve to the wrong thing.
- **`see --json` bounds are screen coordinates**; the **snapshot ID** is what makes an element action stable.
- Reach for **coordinates only** when accessibility metadata is missing.
- Use `--json` (alias `--json-output`) whenever the result is parsed — pipe to `jaq`, never grep the JSON.

## Capture modes — and the glass-panel gotcha

```bash
peekaboo image --mode screen                       # full display — always works
peekaboo image --mode area --region "x,y,w,h"      # scoped rect — the reliable scoped path
peekaboo image --app Safari --mode window          # window-isolated — SEE WARNING
```

**Window-isolated capture returns a blank PNG for borderless / non-activating / `.glassEffect` panels** (Spotlight-style overlays, HUDs). With `isOpaque=false` and a clear background, window capture has no backdrop to composite the glass against — verified blank on every engine. This is a macOS compositing fact, not a Peekaboo bug. For such panels, use `--mode screen` or `--mode area` driven off the panel's real frame, or skip pixels entirely (next section).

## Functional verification beats screenshots

Full-screen captures are often too low-res to read, and window capture blanks on glass. The robust signal is to **drive, then read the result** — not the pixels:

- Action emits to stdout → read the process's stdout.
- Action copies to clipboard → `printf SENTINEL | pbcopy` first, fire the action, then `pbpaste`; the sentinel surviving means nothing happened.
- App logs structured events → `log stream` *before* the action (see `references/verification-patterns.md` — `.info` logs are not persisted, so post-hoc `log show` misses them).

Driving and observing are independent: synthetic keystrokes reach the app regardless of which capture mode (or none) is used.

## Driving input (quick map — `--help` for flags)

| Need | Command |
|------|---------|
| Type text into the focused field | `peekaboo type "text"` (`--clear`, `--delay`) |
| A single key / named key | `peekaboo press return` (`tab`, `escape`, `down`…) |
| A modifier chord | `peekaboo hotkey cmd,shift,t` |
| Click an element / coords | `peekaboo click --on elem_N --snapshot <id>` / `--coords x,y` |
| Set-clipboard→paste→restore | `peekaboo paste "text"` |
| Scroll / drag / swipe / move | `peekaboo scroll` / `drag` / `swipe` / `move` |
| App menus / status-bar items | `peekaboo menu …` / `peekaboo menubar …` |

`press` fires named keys; there is **no `peekaboo key`** command. Multi-step synthetic chains race async UI (reloads, animations, nav pushes) — prefer a single-step assertion, or `peekaboo sleep <ms>` / a re-`see` between steps. For deterministic multi-step flows, author a `.peekaboo.json` and run it with `peekaboo run`.

## Clean slate before a repro

Stale or duplicate instances of the target app silently confound results (one answers, another holds a socket). Before a fresh repro, kill leftovers and confirm none remain:

```bash
pkill -KILL <ProcessName>; pgrep <ProcessName>   # expect no output
```

A capture that "worked yesterday" returning blank is more often a stale process or a revoked TCC grant than a real regression — re-check Step 0 first.

## Additional resources

- **`references/command-map.md`** — the full CLI command catalog by category (Vision/Capture, Interaction, Windows/Menus/Apps, Automation), with the live-source caveat. Use it to pick the right command.
- **`references/verification-patterns.md`** — the deep field-tested patterns: UIAX vs synthetic input-path testing (`--input-strategy actionOnly|synthOnly`, `perform-action AXPress`), `log stream` verification and the `.info`-not-persisted trap, the glass-panel capture forensics, and `.peekaboo.json` run scripts.
