## Claude Code hook for Stop / Notification / AskUserQuestion events.
##
## Dispatches to a pluggable array of notifier backends. Each backend is a
## single proc that owns its own availability check and returns 0+ argv
## lists to spawn. Dispatch fans them out concurrently and waits on all.
##
## Built-in backends:
##   - appriseNotifier — desktop toast via apprise CLI (always, if installed)
##   - grrrNotifier    — growlrrr w/ click-to-focus (only when in Zellij)
##
## To add a new backend:
##   1. Write a `proc fooNotifier(n: Notification): seq[seq[string]]`.
##      Return `@[]` to decline (backend unavailable, wrong env, etc.);
##      otherwise return one or more argv lists to spawn concurrently.
##   2. Append `fooNotifier` to the `notifiers` array.
##   3. `chezmoi apply` — source hash changes, build template rebuilds.
##
## Usage (cligen dispatchMulti):
##   notify Stop < stdin.json
##   notify Notification < stdin.json
##   notify PreToolUse < stdin.json   # no-op unless tool_name=AskUserQuestion
##
## Suppressed when:
##   - called more than once per RateLimitSeconds for the same project
##   - the current terminal is focused AND user isn't idle

import std/[json, os, osproc, strutils, times, tempfiles, streams]
import cligen

# std/md5 is deprecated in favor of the `checksums` nimble package, but it
# still works and we only need a short hash for rate-limit filenames — not
# worth pulling another dep for.
{.push warning[Deprecated]: off.}
import std/md5
{.pop.}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const
  RateLimitSeconds = 10
  IdleThresholdSeconds = 300

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

type
  Priority = enum
    prNormal
    prHigh

  Notification = object
    title, body, subtitle, threadId: string
    priority: Priority

  Notifier = proc(n: Notification): seq[seq[string]] {.nimcall.}
    ## Returns 0+ argv lists to spawn. Empty seq = notifier declines.

# ---------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------

proc runCapture(cmd: string, args: openArray[string]): string =
  ## Runs cmd with args, returns trimmed stdout. Returns "" on any failure.
  try:
    let p = startProcess(cmd, args = @args, options = {poUsePath, poStdErrToStdOut})
    defer:
      p.close()
    result = p.outputStream.readAll().strip()
    if p.waitForExit() != 0:
      result = ""
  except OSError, IOError:
    result = ""

proc tryParseJson(s: string): JsonNode =
  ## parseJson wrapper that returns nil on malformed input instead of raising.
  if s.len == 0:
    return nil
  try:
    parseJson(s)
  except JsonParsingError, ValueError:
    nil

# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------

proc rateLimitFile(project: string): string =
  let hash = getMD5(project)[0 ..< 8]
  "/tmp/ntfy-claude-" & hash & ".last"

proc shouldRateLimit(project: string): bool =
  let path = rateLimitFile(project)
  if not fileExists(path):
    return false
  try:
    let last = parseFloat(readFile(path).strip())
    return (epochTime() - last) < RateLimitSeconds.float
  except ValueError, IOError, OSError:
    return false

proc recordNotification(project: string) =
  try:
    writeFile(rateLimitFile(project), $epochTime())
  except IOError, OSError:
    discard

# ---------------------------------------------------------------------------
# Focus / idle detection
# ---------------------------------------------------------------------------

proc terminalPid(): int =
  ## Returns the PID of the terminal running this session, or 0 if unknown.
  let bundle = getEnv("__CFBundleIdentifier")
  case bundle
  of "net.kovidgoyal.kitty":
    try:
      parseInt(getEnv("KITTY_PID"))
    except ValueError:
      0
  of "com.github.wez.wezterm":
    let output = runCapture("wezterm", ["cli", "list-clients", "--format", "json"])
    let j = tryParseJson(output)
    if j == nil or j.kind != JArray or j.len == 0:
      return 0
    j[0]{"pid"}.getInt(0)
  else:
    0

proc ghosttyFocusedCwd(): string =
  ## Returns Ghostty's focused terminal cwd via AppleScript, or "".
  const script = """
tell application "Ghostty"
    if not frontmost then return ""
    set focusedWindow to front window
    set activeTab to selected tab of focusedWindow
    set activeTerm to focused terminal of activeTab
    return working directory of activeTerm
end tell"""
  runCapture("osascript", ["-e", script])

proc zellijPaneIsFocused(paneId: string): bool =
  ## Returns true iff our pane is focused on the active Zellij tab.
  ## Caller must verify $ZELLIJ_PANE_ID is set before calling.
  let tabInfo = runCapture("zellij", ["action", "current-tab-info"])
  var activeTabId = -1
  for line in tabInfo.splitLines:
    if line.startsWith("id:"):
      try:
        activeTabId = parseInt(line.split(":", 1)[1].strip())
      except ValueError:
        return false
      break
  if activeTabId < 0:
    return false

  let panesOutput =
    runCapture("zellij", ["action", "list-panes", "--state", "--tab", "--json"])
  let panes = tryParseJson(panesOutput)
  if panes == nil or panes.kind != JArray:
    return false

  let ourPaneId =
    try:
      parseInt(paneId)
    except ValueError:
      return false

  for pane in panes:
    if pane.kind != JObject:
      continue
    if pane{"id"}.getInt(-1) == ourPaneId and not pane{"is_plugin"}.getBool(false):
      return
        pane{"is_focused"}.getBool(false) and pane{"tab_id"}.getInt(-1) == activeTabId
  false

proc zellijTabForPane(paneId: string): int =
  ## Returns the tab ID for a Zellij pane, or -1 if not found.
  let panesOutput = runCapture("zellij", ["action", "list-panes", "--tab", "--json"])
  let panes = tryParseJson(panesOutput)
  if panes == nil or panes.kind != JArray:
    return -1

  let ourPaneId =
    try:
      parseInt(paneId)
    except ValueError:
      return -1

  for pane in panes:
    if pane.kind != JObject:
      continue
    if pane{"id"}.getInt(-1) == ourPaneId and not pane{"is_plugin"}.getBool(false):
      return pane{"tab_id"}.getInt(-1)
  -1

proc isTerminalFocused(): bool =
  ## Macos-specific. Returns true when the terminal running this session is
  ## the frontmost focused app (per aerospace) AND, when in Zellij, our pane
  ## is the focused one on the active tab.
  let zellijPaneId = getEnv("ZELLIJ_PANE_ID")
  if zellijPaneId.len > 0 and not zellijPaneIsFocused(zellijPaneId):
    return false

  let output = runCapture(
    "aerospace",
    ["list-windows", "--focused", "--json", "--format", "%{app-name}%{tab}%{app-pid}"],
  )
  let windows = tryParseJson(output)
  if windows == nil or windows.kind != JArray or windows.len == 0:
    return false

  let focused = windows[0]
  if focused.kind != JObject:
    return false
  let focusedApp = focused{"app-name"}.getStr("")
  let focusedPid = focused{"app-pid"}.getInt(0)

  let bundle = getEnv("__CFBundleIdentifier")
  if bundle == "com.mitchellh.ghostty":
    if focusedApp != "ghostty":
      return false
    return ghosttyFocusedCwd() == getCurrentDir()

  let ourPid = terminalPid()
  if ourPid > 0:
    return focusedPid == ourPid
  false

proc systemIdle(threshold = IdleThresholdSeconds): bool =
  ## Parses `ioreg -c IOHIDSystem` for HIDIdleTime (ns) and compares to
  ## threshold seconds.
  let output = runCapture("ioreg", ["-c", "IOHIDSystem"])
  for line in output.splitLines:
    if "HIDIdleTime" in line:
      let parts = line.split("=", 1)
      if parts.len == 2:
        try:
          let idleNs = parseBiggestInt(parts[1].strip())
          return (idleNs div 1_000_000_000).int > threshold
        except ValueError:
          return false
  false

# ---------------------------------------------------------------------------
# Notifier backends
# ---------------------------------------------------------------------------

proc buildZellijFocusScript(paneId: string, tabId: int): string =
  ## Writes a shell script that reactivates the terminal bundle and focuses
  ## the correct Zellij tab + pane. Returns the path. Executable (0755).
  let session = getEnv("ZELLIJ_SESSION_NAME")
  let socketDir = getEnv("ZELLIJ_SOCKET_DIR", "/tmp/zellij")
  let zellij = findExe("zellij")
  let zellijBin = if zellij.len > 0: zellij else: "zellij"
  let bundle = getEnv("__CFBundleIdentifier")
  let activate =
    if bundle.len > 0:
      "open -b " & bundle & "\n"
    else:
      ""

  let content =
    "#!/bin/sh\n" & activate & "export ZELLIJ_SOCKET_DIR=" & socketDir & "\n" & zellijBin &
    " -s " & session & " action go-to-tab-by-id " & $tabId & "\n" & zellijBin & " -s " &
    session & " action focus-pane-id terminal_" & paneId & "\n"

  let (file, path) = createTempFile("zellij-focus-", ".sh")
  file.write(content)
  file.close()
  setFilePermissions(
    path,
    {
      fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupExec, fpOthersRead,
      fpOthersExec,
    },
  )
  path

proc appriseNotifier(n: Notification): seq[seq[string]] =
  ## Standard desktop toast via apprise CLI. Unavailable if apprise is
  ## missing from PATH.
  if findExe("apprise").len == 0:
    return @[]
  let fullTitle =
    if n.subtitle.len > 0:
      n.title & " — " & n.subtitle
    else:
      n.title
  @[@["apprise", "-t", fullTitle, "-b", n.body, "-i", "markdown"]]

proc grrrNotifier(n: Notification): seq[seq[string]] =
  ## Growlrrr with click-to-focus. Zellij-only: uses the session's tab/pane
  ## IDs to drop a shell script that jumps back to the right place on click.
  let paneId = getEnv("ZELLIJ_PANE_ID")
  if paneId.len == 0:
    return @[]
  let grrr = findExe("grrr")
  if grrr.len == 0:
    return @[]

  var cmd = @[grrr, "--appId", "Luna", "--title", n.title]
  if n.subtitle.len > 0:
    cmd.add "--subtitle"
    cmd.add n.subtitle

  let tabId = zellijTabForPane(paneId)
  if tabId >= 0:
    cmd.add "--execute"
    cmd.add buildZellijFocusScript(paneId, tabId)
  else:
    cmd.add "--reactivate"

  cmd.add n.body
  @[cmd]

# To add a new backend: write a `Notifier` proc and append it here.
let notifiers: array[2, Notifier] = [appriseNotifier, grrrNotifier]

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

proc dispatch(n: Notification) =
  ## Fans out to every registered notifier concurrently, waits on all.
  var procs: seq[Process] = @[]
  for notifier in notifiers:
    for argv in notifier(n):
      if argv.len == 0:
        continue
      try:
        procs.add startProcess(argv[0], args = argv[1 ..^ 1], options = {poUsePath})
      except OSError:
        discard
  for p in procs:
    discard p.waitForExit()
    p.close()

proc send(
    title, body, project: string,
    subtitle = "",
    threadId = "",
    priority: Priority = prNormal,
) =
  if shouldRateLimit(project):
    return
  if isTerminalFocused() and not systemIdle():
    return
  let n = Notification(
    title: title, body: body, subtitle: subtitle, threadId: threadId, priority: priority
  )
  dispatch(n)
  recordNotification(project)

# ---------------------------------------------------------------------------
# Event handlers (pure data munging, then call send)
# ---------------------------------------------------------------------------

func notificationTitle(kind: string): string =
  case kind
  of "permission_prompt": "🔐 Needs Approval"
  of "idle_prompt": "⏸️ Waiting For Next Steps"
  of "auth_success": "🔑 Auth Complete"
  of "elicitation_dialog": "📋 Input Needed"
  else: "⏳ Waiting"

func scrubStopBody(msg: string): string =
  ## Strips *action-beat* lines and blank lines. Falls back to a default
  ## body if nothing remains.
  var keep: seq[string] = @[]
  for line in msg.splitLines:
    let stripped = line.strip()
    if stripped.len > 0 and not stripped.startsWith("*"):
      keep.add line
  if keep.len > 0:
    keep.join("\n")
  else:
    "Task completed"

const questionKeys = ["question", "prompt", "message", "text"]

func extractQuestion(toolInput: JsonNode): string =
  ## Pulls question text from AskUserQuestion input, checking known fields.
  if toolInput == nil or toolInput.kind != JObject:
    return "Question"
  let questions = toolInput{"questions"}
  if questions != nil and questions.kind == JArray and questions.len > 0:
    let first = questions[0]
    if first.kind == JObject:
      for key in questionKeys:
        let val = first{key}.getStr("")
        if val.len > 0:
          return val
  for key in questionKeys:
    let val = toolInput{key}.getStr("")
    if val.len > 0:
      return val
  "Question"

func extractOptions(toolInput: JsonNode): seq[string] =
  if toolInput == nil or toolInput.kind != JObject:
    return @[]
  let questions = toolInput{"questions"}
  if questions == nil or questions.kind != JArray or questions.len == 0:
    return @[]
  let options = questions[0]{"options"}
  if options == nil or options.kind != JArray:
    return @[]
  var i = 0
  for opt in options:
    if i >= 4:
      break
    if opt.kind == JObject:
      result.add opt{"label"}.getStr("")
    inc i

proc handleStop(data: JsonNode) =
  let cwd = data{"cwd"}.getStr("").lastPathPart
  let session = data{"session_id"}.getStr("")
  let msg = data{"last_assistant_message"}.getStr("Task completed")
  send(
    title = "✅ Task Complete",
    body = scrubStopBody(msg),
    project = cwd,
    subtitle = cwd,
    threadId = session,
  )

proc handleNotification(data: JsonNode) =
  let cwd = data{"cwd"}.getStr("").lastPathPart
  let session = data{"session_id"}.getStr("")
  let kind = data{"notification_type"}.getStr("")
  let title = notificationTitle(kind)
  let msg = data{"message"}.getStr("Waiting for input")
  send(
    title = title,
    body = msg,
    project = cwd,
    subtitle = cwd,
    threadId = session,
    priority = prHigh,
  )

proc handlePreToolUse(data: JsonNode) =
  let tool = data{"tool_name"}.getStr("")
  if tool != "AskUserQuestion":
    return
  let cwd = data{"cwd"}.getStr("").lastPathPart
  let session = data{"session_id"}.getStr("")
  let toolInput = data{"tool_input"}
  let question = extractQuestion(toolInput)
  let options = extractOptions(toolInput)
  var body = question
  if options.len > 0:
    body &= "\n→ " & options.join(" | ")
  send(
    title = "❓ Question",
    body = body,
    project = cwd,
    subtitle = cwd,
    threadId = session,
    priority = prHigh,
  )

# ---------------------------------------------------------------------------
# CLI entry (cligen dispatchMulti)
# ---------------------------------------------------------------------------

proc readStdinPayload(): JsonNode =
  try:
    parseJson(stdin.readAll())
  except JsonParsingError, ValueError, IOError:
    nil

proc stop() =
  ## Stop event — fires "✅ Task Complete" when an assistant turn ends.
  let data = readStdinPayload()
  if data != nil:
    handleStop(data)

proc notification() =
  ## Notification event — permission prompts, idle, auth, elicitation.
  let data = readStdinPayload()
  if data != nil:
    handleNotification(data)

proc preToolUse() =
  ## PreToolUse event — reacts only to AskUserQuestion; no-op otherwise.
  let data = readStdinPayload()
  if data != nil:
    handlePreToolUse(data)

when isMainModule:
  dispatchMulti(
    [stop, cmdName = "Stop"],
    [notification, cmdName = "Notification"],
    [preToolUse, cmdName = "PreToolUse"],
  )
