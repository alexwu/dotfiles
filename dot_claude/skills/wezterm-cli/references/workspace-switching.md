# Switching the active workspace from the CLI

`wezterm cli` has **no native command to switch the active workspace.** There is
no `activate-workspace`, `switch-workspace`, or `activate-window`.
`rename-workspace` only *renames* the current workspace — it does not switch to
one. `activate-pane` / `activate-tab` move focus *within* a workspace and do not
cross workspace boundaries.

Switching workspaces from a script needs a workaround.

## Why there's no native command

Tracked in **wez/wezterm#3542** ("Add `activate-window` command to wezterm cli")
— open since April 2023, still no PR (re-check before assuming this doc is
current). wez's reasoning: `wezterm cli` speaks the *Mux* protocol, but
workspace focus is a *GUI-layer* concept — it controls which Mux windows a GUI
window renders — with no Mux object to address. It needs design work that
hasn't happened.

The workaround below is the community standard, endorsed by wez in **#2979**
(comment 1447519267 — origin of the pattern) and **discussion #3534**.

## The workaround: the SetUserVar OSC bridge

A program running *inside* a WezTerm pane can push data to the GUI's Lua layer
with an `OSC 1337 ; SetUserVar` escape sequence. A
`wezterm.on("user-var-changed", ...)` handler in `wezterm.lua` catches it and
runs any action — including `SwitchToWorkspace`.

**1. Emit the OSC** into a pane's output stream. The user-var *name* is literal;
the *value* is base64:

```sh
b64=$(printf '%s' '{"workspace":"my-project"}' | base64 | tr -d '\n')
printf '\033]1337;SetUserVar=switch-workspace=%s\007' "$b64"
```

From a shell *inside* the pane, `printf` to stdout is enough. From *outside*
WezTerm (e.g. a detached script with no tty of its own), write the sequence to
the pane's tty device — `tty_name` is in `wezterm cli list --format json`:

```sh
printf '\033]1337;SetUserVar=switch-workspace=%s\007' "$b64" > /dev/ttysNNN
```

**2. Catch it** in `wezterm.lua`:

```lua
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "switch-workspace" then
    local ctx = wezterm.json_parse(value)
    window:perform_action(
      wezterm.action.SwitchToWorkspace({ name = ctx.workspace }),
      pane
    )
  end
end)
```

`SwitchToWorkspace` takes an **absolute** workspace name — so it doesn't matter
which pane fires the OSC, only *where that pane lives* (see below).

## Critical gotcha: emit from an active-workspace pane

The handler only switches the workspace when the OSC is emitted into a pane
belonging to the **currently active** workspace. Emitting into a pane in a
*background* workspace does nothing — the handler's `window` argument is not a
usable GUI window when the emitting pane's workspace isn't on screen. (Observed
behaviour, confirmed both ways.)

That is a chicken-and-egg for "switch *to* a background workspace": you must
fire the OSC *from* the foreground one. Resolve the active workspace's pane at
the moment you switch:

```sh
ws=$(wezterm cli list-clients --format json | jaq -r '.[0].workspace')
tty=$(wezterm cli list --format json \
  | jaq -r --arg w "$ws" '[.[] | select(.workspace == $w) | .tty_name] | .[0] // ""')
[ -n "$tty" ] && printf '\033]1337;SetUserVar=switch-workspace=%s\007' "$b64" > "$tty"
```

Since `SwitchToWorkspace` targets by name, firing from any active-workspace pane
switches correctly to wherever you asked.

## This machine's wiring — custom to these dotfiles

> The user-var name `switch-workspace`, the `{workspace, cwd}` JSON shape, and
> the file paths below are **local convention, not WezTerm API**. The portable
> part is the OSC mechanism above; anyone reusing it picks their own names.
> Listed here so the moving parts are findable.

Three pieces cooperate:

- **`dot_zsh/macos.zsh`** — `wezterm-switch-workspace()` shell function: `jq -n`
  a `{workspace, cwd}` blob, base64 it, `printf` the OSC. The hand-driven entry
  point.
- **`dot_config/wezterm/wezterm.lua`** — the `user-var-changed` handler keyed on
  the `switch-workspace` user var. Calls
  `act.SwitchToWorkspace{ name, spawn = { cwd, args = zmx_cmd } }`; the `spawn`
  only fires when the workspace doesn't already exist.
- **`scripts/claude/notify.nim`** — `buildWeztermFocusScript` generates a
  click-to-focus script for growlrr notifications. When the notifying session
  lives in a background workspace, the script resolves the active-workspace
  pane's tty at *click* time (per the gotcha) and emits the OSC there, then runs
  `activate-tab` + `activate-pane` for the exact tab and pane.
