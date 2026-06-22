## Claude Code hook for Notification / AskUserQuestion events.
##
## Fires only when Claude is blocked on you: permission prompts, input
## dialogs, the idle "your turn" nudge, and AskUserQuestion. Per-turn Stop
## ("task complete") notifications were dropped on purpose — the idle_prompt
## notification already covers the walked-away case for tasks of any length.
##
## Dispatches to a pluggable array of notifier backends. Each backend is a
## single proc that owns its own availability check and returns 0+ argv
## lists to spawn. Dispatch fans them out concurrently and waits on all.
##
## Built-in backends:
##   - appriseNotifier — desktop toast via apprise CLI (always, if installed)
##   - grrrNotifier    — growlrrr (always, if installed); click-to-focus when
##                       in Zellij or WezTerm, --reactivate otherwise
##
## To add a new backend:
##   1. Write a `proc fooNotifier(n: Notification): seq[seq[string]]`.
##      Return `@[]` to decline (backend unavailable, wrong env, etc.);
##      otherwise return one or more argv lists to spawn concurrently.
##   2. Append `fooNotifier` to the `notifiers` array.
##   3. `chezmoi apply` — source hash changes, build template rebuilds.
##
## Usage (cligen dispatchMulti):
##   notify Notification < stdin.json
##   notify PreToolUse < stdin.json   # no-op unless tool_name=AskUserQuestion
##
## Suppressed when:
##   - called more than once per RateLimitSeconds for the same project
##   - the current terminal is focused AND user isn't idle

import std/[base64, json, os, osproc, strutils, times, tempfiles, streams]
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
# Notification identity (per-session, per-agent)
# ---------------------------------------------------------------------------

# Per-agent detection for the notification-identifier namespace, so concurrent
# sessions of different agents (and the dismiss that clears them) never collide.
#
# Documented, tool-specific signals come FIRST because they're the reliable
# ones — CLAUDECODE is the env var Anthropic actually documents and commits to.
# The generic slug vars below are the fallback catch:
#   - AI_AGENT  — undocumented/observed-only; Claude Code sets
#     `claude-code_2-1-183_agent` (slug_version_agent), but it's absent from the
#     official env-vars reference and could change without notice.
#   - AGENT     — the emerging cross-agent convention (Goose/Amp set a slug),
#     but its value is contested (some tools set AGENT=1 as a boolean) and
#     Claude Code declined to adopt it (anthropics/claude-code#24838).
# Extend by appending a marker row (preferred) or relying on AGENT/AI_AGENT.
const
  agentMarkers = [
    ("LULU_AGENT", "lulu"),
      # our own agent's base indicator (lulu-agent: AgentIdentity.env_vars,
      # always "1" for any lulu-spawned subprocess; session id NOT guaranteed)
    ("CLAUDECODE", "claude-code"), # documented, stable
    ("CURSOR_AGENT", "cursor"),
    ("GEMINI_CLI", "gemini"),
    ("CODEX_SANDBOX", "codex"),
    ("GOOSE_TERMINAL", "goose"),
  ]
  genericAgentVars = ["AGENT", "AI_AGENT"]

proc slugFromGeneric(v: string): string =
  ## Slug from a generic AGENT/AI_AGENT value (leading token before `_`),
  ## ignoring the boolean forms some tools use. "" when not slug-like.
  if v.len == 0 or v in ["1", "true", "0", "false"]:
    return ""
  v.split('_')[0]

proc agentSlug(): string =
  ## Identifies the host agent. Documented markers first, then the generic
  ## slug vars, then "luna".
  for (envVar, slug) in agentMarkers:
    if getEnv(envVar).len > 0:
      return slug
  for envVar in genericAgentVars:
    let slug = slugFromGeneric(getEnv(envVar))
    if slug.len > 0:
      return slug
  "luna"

proc notifId(session: string): string =
  ## Per-session notification identifier for grrr send/clear, or "" when there
  ## is no session id (an un-keyed send that can't be dismissed — old behavior).
  if session.len == 0:
    ""
  else:
    agentSlug() & "-" & session

# ---------------------------------------------------------------------------
# Notification state (per-session scratch in /tmp)
# ---------------------------------------------------------------------------

# Tools that can be permission-gated and are worth naming in a permission
# notification. Also the PostToolUse set whose completion (an accepted prompt)
# should dismiss the notification.
const
  gatedTools = ["Bash", "Edit", "Write", "MultiEdit", "NotebookEdit", "WebFetch"]
  PendingFreshSeconds = 60

proc activeFlagFile(session: string): string =
  "/tmp/notify-active-" & session & ".flag"

proc pendingFile(session: string): string =
  "/tmp/notify-pending-" & session & ".json"

proc markActive(session: string) =
  ## Record that a notification is currently showing for this session, so the
  ## dismiss path can skip the cost of spawning grrr when nothing is pending.
  if session.len == 0:
    return
  try:
    writeFile(activeFlagFile(session), "")
  except IOError, OSError:
    discard

proc dismissSession(session: string) =
  ## Clear this session's grrr notification — but only when one is actually
  ## outstanding (the flag is the cheap guard so PostToolUse can fire on every
  ## gated tool without spawning grrr each time). Keyed per-session, so it never
  ## touches another concurrent session's notification.
  if session.len == 0:
    return
  let flag = activeFlagFile(session)
  if not fileExists(flag):
    return
  try:
    removeFile(flag)
  except OSError:
    discard
  let grrr = findExe("grrr")
  if grrr.len == 0:
    return
  let ident = notifId(session)
  if ident.len == 0:
    return
  try:
    let p =
      startProcess(grrr, args = ["clear", "--delivered", ident], options = {poUsePath})
    discard p.waitForExit()
    p.close()
  except OSError:
    discard

func describeTool(tool: string, toolInput: JsonNode): string =
  ## One-line summary of what a gated tool is about to do, for permission detail.
  if toolInput == nil or toolInput.kind != JObject:
    return ""
  case tool
  of "Bash": toolInput{"command"}.getStr("")
  of "Edit", "Write", "MultiEdit", "NotebookEdit": toolInput{"file_path"}.getStr("")
  of "WebFetch": toolInput{"url"}.getStr("")
  else: ""

proc writePending(session, tool: string, toolInput: JsonNode) =
  ## Stash the most recent gated tool call so a permission notification can name
  ## it. The permission prompt fires right after this tool's PreToolUse, so the
  ## freshest entry is the one being gated.
  if session.len == 0:
    return
  try:
    writeFile(
      pendingFile(session),
      $(%*{"tool": tool, "detail": describeTool(tool, toolInput), "ts": epochTime()}),
    )
  except IOError, OSError:
    discard

proc readPending(session: string): tuple[tool, detail: string] =
  ## The stashed gated tool, or ("", "") when absent or stale (older than
  ## PendingFreshSeconds — guards against naming an unrelated earlier call when
  ## the gated tool wasn't one we captured).
  result = ("", "")
  if session.len == 0:
    return
  var raw = ""
  try:
    raw = readFile(pendingFile(session))
  except IOError, OSError:
    return
  let j = tryParseJson(raw)
  if j == nil or j.kind != JObject:
    return
  if epochTime() - j{"ts"}.getFloat(0) > PendingFreshSeconds.float:
    return
  result = (j{"tool"}.getStr(""), j{"detail"}.getStr(""))

proc clearSessionState(session: string) =
  ## Remove this session's scratch files (SessionEnd cleanup).
  if session.len == 0:
    return
  for f in [activeFlagFile(session), pendingFile(session)]:
    try:
      removeFile(f)
    except OSError:
      discard

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

proc weztermPaneInfo(paneId: string): tuple[tabId: int, workspace: string] =
  ## Returns the WezTerm tab ID and workspace name hosting a pane.
  ## tabId is -1 and workspace "" when the pane can't be found.
  result = (tabId: -1, workspace: "")
  let output = runCapture("wezterm", ["cli", "list", "--format", "json"])
  let panes = tryParseJson(output)
  if panes == nil or panes.kind != JArray:
    return

  let ourPaneId =
    try:
      parseInt(paneId)
    except ValueError:
      return

  for pane in panes:
    if pane.kind != JObject:
      continue
    if pane{"pane_id"}.getInt(-1) == ourPaneId:
      return (tabId: pane{"tab_id"}.getInt(-1), workspace: pane{"workspace"}.getStr(""))

proc weztermPaneIsFocused(paneId: string): bool =
  ## Returns true iff our pane is WezTerm's focused pane — which implies its
  ## tab and workspace are active too (there is only one focused pane).
  ## Caller must verify $WEZTERM_PANE is set before calling.
  let output = runCapture("wezterm", ["cli", "list-clients", "--format", "json"])
  let clients = tryParseJson(output)
  if clients == nil or clients.kind != JArray or clients.len == 0:
    return false

  let ourPaneId =
    try:
      parseInt(paneId)
    except ValueError:
      return false

  clients[0]{"focused_pane_id"}.getInt(-1) == ourPaneId

proc isTerminalFocused(): bool =
  ## Macos-specific. Returns true when the terminal running this session is
  ## the frontmost focused app (per aerospace) AND — in Zellij or WezTerm —
  ## our pane is the focused one. A backgrounded pane/tab/workspace counts as
  ## not focused, so the notification still fires.
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
  if ourPid <= 0 or focusedPid != ourPid:
    return false

  # WezTerm: being the frontmost app isn't enough — the agent's pane must
  # also be WezTerm's focused pane (which implies its tab and workspace are
  # active). On another pane/tab/workspace the session is off-screen, so the
  # notification should still fire.
  let weztermPane = getEnv("WEZTERM_PANE")
  if bundle == "com.github.wez.wezterm" and weztermPane.len > 0:
    return weztermPaneIsFocused(weztermPane)
  true

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

proc buildWeztermFocusScript(paneId: string, tabId: int, workspace: string): string =
  ## Writes a shell script that brings WezTerm to the front, switches to the
  ## target workspace, activates the tab, then focuses the pane. Returns the
  ## path. Executable (0755).
  ##
  ## `wezterm cli` has no native workspace-switch command, so the workspace
  ## hop rides the SetUserVar OSC bridge — a `user-var-changed` handler in
  ## wezterm.lua calls SwitchToWorkspace. That handler only fires usefully
  ## when the OSC lands in a pane belonging to the *currently active*
  ## workspace, so the script resolves that pane's tty at click time rather
  ## than baking the agent's own (likely backgrounded) pane.
  let wezterm = findExe("wezterm")
  let weztermBin = if wezterm.len > 0: wezterm else: "wezterm"

  var content = "#!/bin/sh\nopen -b com.github.wez.wezterm\n"

  if workspace.len > 0:
    let jaq = findExe("jaq")
    let jaqBin = if jaq.len > 0: jaq else: "jaq"
    let payload = encode($(%*{"workspace": workspace}))
    content.add(
      "ws=$(" & weztermBin & " cli list-clients --format json | " & jaqBin &
        " -r '.[0].workspace')\n" & "tty=$(" & weztermBin & " cli list --format json | " &
        jaqBin & " -r --arg w \"$ws\" " &
        "'[.[] | select(.workspace == $w) | .tty_name] | .[0] // \"\"')\n" &
        "[ -n \"$tty\" ] && printf " & "'\\033]1337;SetUserVar=switch-workspace=" &
        payload & "\\007' > \"$tty\"\n"
    )

  content.add(
    weztermBin & " cli activate-tab --tab-id " & $tabId & "\n" & weztermBin &
      " cli activate-pane --pane-id " & paneId & "\n"
  )

  let (file, path) = createTempFile("wezterm-focus-", ".sh")
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
  ## Growlrrr. Fires for every notification (like apprise). Attaches a
  ## click-to-focus script when running inside Zellij or WezTerm — both jump
  ## to the right tab + pane; outside both, or when the pane can't be
  ## resolved, it falls back to --reactivate. Unavailable only when grrr is
  ## missing from PATH.
  let grrr = findExe("grrr")
  if grrr.len == 0:
    return @[]

  var cmd = @[grrr, "--appId", "Luna", "--title", n.title]
  # Per-session identifier so a later UserPromptSubmit can clear this exact
  # notification (and only this session's). n.threadId is the session id.
  let ident = notifId(n.threadId)
  if ident.len > 0:
    cmd.add "--identifier"
    cmd.add ident
  if n.subtitle.len > 0:
    cmd.add "--subtitle"
    cmd.add n.subtitle

  let zellijPane = getEnv("ZELLIJ_PANE_ID")
  let zellijTab =
    if zellijPane.len > 0:
      zellijTabForPane(zellijPane)
    else:
      -1
  if zellijTab >= 0:
    cmd.add "--execute"
    cmd.add buildZellijFocusScript(zellijPane, zellijTab)
  else:
    # Resolved lazily — skip the `wezterm cli list` subprocess when the
    # Zellij branch already won (e.g. Zellij running inside WezTerm).
    let weztermPane = getEnv("WEZTERM_PANE")
    let (weztermTab, weztermWs) =
      if weztermPane.len > 0:
        weztermPaneInfo(weztermPane)
      else:
        (tabId: -1, workspace: "")
    if weztermTab >= 0:
      cmd.add "--execute"
      cmd.add buildWeztermFocusScript(weztermPane, weztermTab, weztermWs)
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
  markActive(threadId)

# ---------------------------------------------------------------------------
# Event handlers (pure data munging, then call send)
# ---------------------------------------------------------------------------

func notificationTitle(kind: string): string =
  case kind
  of "permission_prompt": "🔐 Needs Approval"
  of "idle_prompt": "⏸️ Waiting For Next Steps"
  of "elicitation_dialog": "📋 Input Needed"
  else: "⏳ Waiting"

# Notification types worth a ping — each means Claude is blocked on you or
# it's your turn. Informational types (auth_success, elicitation_complete,
# elicitation_response) are dropped.
const notifyTypes = ["permission_prompt", "idle_prompt", "elicitation_dialog"]

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

proc handleNotification(data: JsonNode) =
  let kind = data{"notification_type"}.getStr("")
  if kind notin notifyTypes:
    return
  let cwd = data{"cwd"}.getStr("").lastPathPart
  let session = data{"session_id"}.getStr("")
  let title = notificationTitle(kind)
  var msg = data{"message"}.getStr("Waiting for input")
  # The Notification payload carries no tool detail for permission prompts, so
  # name the gated tool from the PreToolUse capture instead of the generic
  # "Claude needs your permission".
  if kind == "permission_prompt":
    let (tool, detail) = readPending(session)
    if tool.len > 0:
      msg =
        if detail.len > 0:
          tool & ": " & detail
        else:
          tool
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
  # Stash gated tool calls so a following permission_prompt can name what's
  # being requested (see handleNotification). These aren't notifications.
  if tool in gatedTools:
    writePending(data{"session_id"}.getStr(""), tool, data{"tool_input"})
    return
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

proc handleUserPromptSubmit(data: JsonNode) =
  ## Clears this session's stale grrr notification when a new prompt is sent —
  ## the "your turn" ping is out of date the moment you reply. Only the grrr
  ## backend is dismissable (apprise toasts are fire-and-forget).
  dismissSession(data{"session_id"}.getStr(""))

proc handlePostToolUse(data: JsonNode) =
  ## Also clears the notification when you resolve what blocked it without
  ## typing a prompt: answering an AskUserQuestion, or accepting a permission
  ## prompt (the gated tool then runs and fires PostToolUse). A no-op unless a
  ## notification is actually outstanding. (Denial fires no PostToolUse, so that
  ## case clears on the next typed prompt instead.)
  dismissSession(data{"session_id"}.getStr(""))

proc handleSessionEnd(data: JsonNode) =
  clearSessionState(data{"session_id"}.getStr(""))

# ---------------------------------------------------------------------------
# CLI entry (cligen dispatchMulti)
# ---------------------------------------------------------------------------

proc readStdinPayload(): JsonNode =
  try:
    parseJson(stdin.readAll())
  except JsonParsingError, ValueError, IOError:
    nil

proc notification() =
  ## Notification event — permission prompts, input dialogs, idle "your turn".
  let data = readStdinPayload()
  if data != nil:
    handleNotification(data)

proc preToolUse() =
  ## PreToolUse event — reacts only to AskUserQuestion; no-op otherwise.
  let data = readStdinPayload()
  if data != nil:
    handlePreToolUse(data)

proc userPromptSubmit() =
  ## UserPromptSubmit event — clears this session's stale notification.
  let data = readStdinPayload()
  if data != nil:
    handleUserPromptSubmit(data)

proc postToolUse() =
  ## PostToolUse event — dismisses the notification on answered question /
  ## accepted permission.
  let data = readStdinPayload()
  if data != nil:
    handlePostToolUse(data)

proc sessionEnd() =
  ## SessionEnd event — removes this session's scratch files.
  let data = readStdinPayload()
  if data != nil:
    handleSessionEnd(data)

when isMainModule:
  dispatchMulti(
    [notification, cmdName = "Notification"],
    [preToolUse, cmdName = "PreToolUse"],
    [userPromptSubmit, cmdName = "UserPromptSubmit"],
    [postToolUse, cmdName = "PostToolUse"],
    [sessionEnd, cmdName = "SessionEnd"],
  )
