## wezrun — a window-scoped `wezterm cli` wrapper for an AI coding agent.
##
## Two subcommands:
##
##   wezrun exec [opts] -- <command...>
##     Run <command> in a visible WezTerm pane, wait for it to finish, print the
##     pane's scrollback (last --lines lines, default 300) to stdout with a
##     `=== wezrun: <cmd> · pane <id> · exit <n> ===` header, and exit with the
##     wrapped command's exit code. Default target pane: a tab titled `claude-run`
##     in the agent's own window (`$WEZTERM_PANE`'s window), created on first use
##     and reused after. `--fresh` spawns a new one; `--split-right`/`--split-bottom`
##     split the agent's pane instead of opening a tab; `--pane-id N` targets an
##     existing pane by id (the explicit opt-in for crossing into another window —
##     a write into another agent's session, so it is never done implicitly).
##     Completion is detected by appending a unique exit-code sentinel
##     (`printf '\n__WEZRUN_<nonce>_DONE_%d__\n' "$?"`) and polling `get-text` for
##     it; the text is sent with `--no-paste` so the trailing newline submits it.
##
##   wezrun capture [opts]
##     Print a pane's scrollback (last --lines lines) to stdout. Default pane: the
##     `claude-run` pane in the agent's own window. `--pane-id N` reads any pane
##     (reading is the relaxed category — explicitly naming a pane is fine).
##
## Exit codes (coreutils-style, à la timeout(1)/env(1)):
##   124  exec timed out waiting for the command to finish
##   125  wezrun itself couldn't run — not inside a WezTerm pane, `wezterm`
##        missing, `wezterm cli list` failed, pane not found, send-text failed
##   else exec exits with the wrapped command's exit code; capture exits 0
## A wrapped command that itself exits 124/125 is ambiguous, but the header line
## always states the parsed exit code explicitly.
##
## No `--kill`: wezrun's internal `wezterm cli kill-pane` would be invisible to the
## `wezterm-guard` PreToolUse hook (which only intercepts the agent's Bash-tool
## calls), so tearing a pane down is left to a raw `wezterm cli kill-pane` command,
## which the guard covers. The reused `claude-run` pane persisting is intentional.
##
## Env: $WEZRUN_TAB_TITLE overrides the default `claude-run` tab title.
##
## Source-only (chezmoi ignores scripts/); compiled to ~/.local/bin/wezrun by the
## `wezrun` stanza in run_onchange_build-scripts.sh.tmpl.

import std/[json, os, osproc, re, strutils, strformat, times, uri, random]

import cligen

const defaultTabTitle = "claude-run"

# ---------- error helpers ----------

proc fail(code: int, msg: string) {.noreturn.} =
  stderr.writeLine "wezrun: " & msg
  quit(code)

template fail125(msg: string) =
  fail(125, msg)

template fail124(msg: string) =
  fail(124, msg)

# ---------- `wezterm cli` helpers ----------
#
# `execCmdEx` runs the command string via `sh -c` (poEvalCommand) and merges
# stderr into the captured output (poStdErrToStdOut). That's fine here — we
# shell-quote any path we interpolate, parse pane ids leniently (wezterm logs an
# INFO line to stderr the first time it spins up the mux), and slice the JSON
# array out of `list`'s output rather than assuming it's the only thing there.

proc weztermList(): JsonNode =
  let (raw, code) = execCmdEx("wezterm cli list --format json")
  if code != 0:
    fail125 "`wezterm cli list` failed (no WezTerm GUI/mux reachable?): " & raw.strip()
  let start = raw.find('[')
  if start < 0:
    fail125 "`wezterm cli list` produced no JSON: " & raw.strip()
  try:
    result = parseJson(raw[start .. ^1])
  except JsonParsingError:
    fail125 "could not parse `wezterm cli list` output as JSON"

proc parsePaneId(raw, ctx: string): int =
  ## Last all-digit line of `raw` — robust to a leading mux-init log line.
  var found = -1
  for ln in raw.splitLines:
    let s = ln.strip()
    if s.len > 0 and s.allCharsInSet({'0' .. '9'}):
      found = parseInt(s)
  if found < 0:
    fail125 ctx & ": no pane id in output: " & raw.strip()
  found

proc paneRow(rows: JsonNode, paneId: int): JsonNode =
  for r in rows:
    if r{"pane_id"}.getInt(-1) == paneId:
      return r
  return nil

proc ownPaneId(): int =
  let wp = getEnv("WEZTERM_PANE").strip()
  if wp.len == 0:
    fail125 "not running inside a WezTerm pane ($WEZTERM_PANE unset) — pass --pane-id"
  try:
    result = parseInt(wp)
  except ValueError:
    fail125 "$WEZTERM_PANE is not an integer: " & wp

proc ownWindowId(rows: JsonNode): int =
  let myPane = ownPaneId()
  let row = paneRow(rows, myPane)
  if row == nil:
    fail125 fmt"pane {myPane} ($WEZTERM_PANE) not in `wezterm cli list` — stale environment?"
  row{"window_id"}.getInt

proc findPaneByTabTitle(rows: JsonNode, title: string, window: int): int =
  ## pane_id of the first pane in `window` whose tab_title == title; -1 if none.
  result = -1
  for r in rows:
    if r{"window_id"}.getInt(-1) == window and r{"tab_title"}.getStr == title:
      return r{"pane_id"}.getInt

proc cwdOf(row: JsonNode): string =
  ## Filesystem path from a row's `cwd` (a `file://<host>/<path>` URL); falls
  ## back to the current directory.
  if row != nil:
    let raw = row{"cwd"}.getStr("")
    if raw.len > 0:
      try:
        let path = parseUri(raw).path
        if path.len > 0:
          return path
      except CatchableError:
        discard
  getCurrentDir()

proc spawnTab(window: int, cwd: string): int =
  let (raw, code) =
    execCmdEx(fmt"wezterm cli spawn --window-id {window} --cwd {quoteShell(cwd)}")
  if code != 0:
    fail125 "`wezterm cli spawn` failed: " & raw.strip()
  parsePaneId(raw, "wezterm cli spawn")

proc splitFrom(fromPane: int, dir, cwd: string): int =
  ## dir = "right" | "bottom"
  let (raw, code) = execCmdEx(
    fmt"wezterm cli split-pane --pane-id {fromPane} --{dir} --cwd {quoteShell(cwd)}"
  )
  if code != 0:
    fail125 fmt"`wezterm cli split-pane --{dir}` failed: " & raw.strip()
  parsePaneId(raw, "wezterm cli split-pane")

proc setTabTitle(pane: int, title: string) =
  discard execCmdEx(fmt"wezterm cli set-tab-title --pane-id {pane} {quoteShell(title)}")

proc getText(pane: int, startLine = 0): string =
  let base = fmt"wezterm cli get-text --pane-id {pane}"
  let cmd = (if startLine == 0: base
  else: base & " --start-line " & $startLine)
  let (raw, code) = execCmdEx(cmd)
  if code != 0:
    fail125 fmt"`wezterm cli get-text --pane-id {pane}` failed (pane gone?): " &
      raw.strip()
  raw

proc effectiveTabTitle(flag: string): string =
  if flag.len > 0:
    return flag
  let env = getEnv("WEZRUN_TAB_TITLE")
  if env.len > 0:
    return env
  defaultTabTitle

proc resolveTargetPane(
    rows: JsonNode, paneId: int, tabTitle: string, fresh, splitRight, splitBottom: bool
): int =
  ## Resolve (or create) the pane `exec` should run in.
  if paneId >= 0:
    if paneRow(rows, paneId) == nil:
      fail125 fmt"no pane with id {paneId} in `wezterm cli list`"
    return paneId
  let myPane = ownPaneId()
  let myWin = ownWindowId(rows)
  let title = effectiveTabTitle(tabTitle)
  # --fresh / --split-* all mean "make a new pane, don't reuse". (If you create
  # several panes with the same --tab-title, plain `wezrun exec` reuses whichever
  # the mux lists first — use distinct --tab-titles or --pane-id to disambiguate.)
  if not (fresh or splitRight or splitBottom):
    let existing = findPaneByTabTitle(rows, title, myWin)
    if existing >= 0:
      return existing
  let cwd = cwdOf(paneRow(rows, myPane))
  # A split pane shares its source pane's tab, so set-tab-title on it would
  # retitle the source pane's tab too (e.g. the agent's own pane) — and that
  # title is what plain `wezrun exec` / `wezrun capture` match on, so a stray
  # cleanup keyed off it could take out the wrong pane. Only a brand-new *tab*
  # gets the title; splits stay untitled (re-target them with --pane-id).
  if splitRight:
    return splitFrom(myPane, "right", cwd)
  if splitBottom:
    return splitFrom(myPane, "bottom", cwd)
  result = spawnTab(myWin, cwd)
  setTabTitle(result, title)

# ---------- subcommands ----------

proc cmdExec(
    paneId = -1,
    tabTitle = "",
    fresh = false,
    splitRight = false,
    splitBottom = false,
    lines = 300,
    timeout = 300,
    cmd: seq[string],
): int =
  ## Run <cmd> in a visible WezTerm pane (default: the `claude-run` pane in this
  ## window, created on first use), wait for it to finish, print the pane's
  ## scrollback (last --lines lines), and exit with the wrapped command's exit
  ## code. Exit 124 = timed out; 125 = wezrun couldn't set up (not in WezTerm,
  ## etc.). `--timeout 0` waits forever.
  if cmd.len == 0:
    stderr.writeLine "wezrun: exec needs a command after `--`"
    return 125
  if splitRight and splitBottom:
    stderr.writeLine "wezrun: --split-right and --split-bottom are mutually exclusive"
    return 125

  let rows = weztermList()
  let target = resolveTargetPane(rows, paneId, tabTitle, fresh, splitRight, splitBottom)

  # Send the command + a unique exit-code sentinel. `--no-paste` so the trailing
  # newline is a real Enter (a bracketed paste would just buffer it). The sentinel
  # is printed by `printf` inside the shell, so `printf` does the \n expansion.
  let nonce = $rand(100_000_000 .. 999_999_999)
  var quoted: seq[string]
  for arg in cmd:
    quoted.add quoteShell(arg)
  let line =
    quoted.join(" ") & " ; printf '\\n__WEZRUN_" & nonce & "_DONE_%d__\\n' \"$?\"\n"
  let (sendRaw, sendCode) =
    execCmdEx(fmt"wezterm cli send-text --pane-id {target} --no-paste", input = line)
  if sendCode != 0:
    fail125 fmt"`wezterm cli send-text --pane-id {target}` failed (pane gone?): " &
      sendRaw.strip()

  # Poll for the sentinel.
  let donePat = re("__WEZRUN_" & nonce & "_DONE_(-?\\d+)__")
  let noLimit = timeout <= 0
  let deadline = epochTime() + (if noLimit: 0.0 else: timeout.float)
  var done = false
  var childExit = -1
  while noLimit or epochTime() < deadline:
    let text = getText(target)
    var m: array[1, string]
    var idx = 0
    while true:
      let f = text.find(donePat, m, idx)
      if f < 0:
        break
      done = true
      try:
        childExit = parseInt(m[0])
      except ValueError:
        discard
      idx = f + 1
    if done:
      break
    sleep(500)
  if not done:
    fail124 fmt"timed out after {timeout}s waiting for command completion in pane {target}"

  # Capture & emit (verbatim — matches what the user sees on screen).
  let scrollback = getText(target, startLine = -lines)
  stdout.writeLine "=== wezrun: " & cmd.join(" ") & " · pane " & $target & " · exit " &
    $childExit & " ==="
  stdout.write scrollback
  if scrollback.len > 0 and not scrollback.endsWith("\n"):
    stdout.write "\n"
  return childExit

proc captureCmd(paneId = -1, tabTitle = "", lines = 300): int =
  ## Print a pane's scrollback (last --lines lines). Default pane: the
  ## `claude-run` pane in this window. Exit 125 if the pane can't be resolved.
  let rows = weztermList()
  var target: int
  if paneId >= 0:
    if paneRow(rows, paneId) == nil:
      fail125 fmt"no pane with id {paneId} in `wezterm cli list`"
    target = paneId
  else:
    let myWin = ownWindowId(rows)
    let title = effectiveTabTitle(tabTitle)
    target = findPaneByTabTitle(rows, title, myWin)
    if target < 0:
      fail125 fmt"no pane titled '{title}' in this window — run `wezrun exec` first, or pass --pane-id"
  stdout.write getText(target, startLine = -lines)
  return 0

when isMainModule:
  randomize()
  dispatchMulti(
    [
      cmdExec,
      cmdName = "exec",
      positional = "cmd",
      help = {
        "paneId":
          "target an existing pane by id (works across windows — explicit opt-in)",
        "tabTitle":
          "reuse/create a pane with this tab title (default: claude-run, or $WEZRUN_TAB_TITLE)",
        "fresh": "always spawn a new pane instead of reusing the claude-run pane",
        "splitRight": "split the current pane to the right instead of opening a new tab",
        "splitBottom": "split the current pane downward instead of opening a new tab",
        "lines": "scrollback lines to capture and print after the command finishes",
        "timeout": "seconds to wait for the command to finish (0 = wait forever)",
      },
    ],
    [
      captureCmd,
      cmdName = "capture",
      help = {
        "paneId": "pane id to read (works across windows)",
        "tabTitle": "pane to read by tab title (this window; default: claude-run)",
        "lines": "scrollback lines to print",
      },
    ],
  )
