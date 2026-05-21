## Claude Code reward re-anchor hook — counter-gated PreToolUse hook that
## injects a reward-contract reminder when Claude is making many edits in
## auto/acceptEdits/bypass mode without checking back in. Sibling to
## persona_anchor; same state-file shape, different event topology.
##
## Subcommands (cligen dispatchMulti):
##   pretooluse  — PreToolUse(Edit|Write|MultiEdit|Agent). Increments the
##                 per-session counter; emits a reminder envelope when the
##                 counter hits a multiple of the configured frequency.
##                 Gated on `permission_mode in {acceptEdits, auto,
##                 bypassPermissions}` — `default` and `plan` already
##                 prompt or aren't editing, so the reminder would be noise.
##   reset       — UserPromptSubmit. Zeros the counter so the metric is
##                 "edits since Alex's last prompt", not "edits this
##                 session". Scope creep is per-turn; the counter should be
##                 too.
##
## Output protocol:
##   - Fires: emits `additionalContext` (no `permissionDecision`) — the
##     reminder rides alongside the tool result without altering the
##     permission flow. PreToolUse accepts additionalContext on its own.
##   - Doesn't fire: silent (exit 0, no output) — wrong tool, wrong mode,
##     counter not at threshold, kill switch set, or stdin payload missing.
##
## Kill switch: `ENABLE_REWARD_ANCHOR=0` → immediate exit 0, no output.
## Tuning:      `REWARD_ANCHOR_FREQUENCY=N` → override default N=8.
##
## State file: `~/.claude/reward_anchor/<session_id>.json`
##   Shape: `{"count": <int>, "last_fired_at": "<iso8601>"}`
##   Survives `--resume`/`--continue`. Parent dir created lazily by
##   `saveState` on first edit. No cleanup hook for now — files are tiny
##   and `persona_anchor` doesn't clean up either.
##
## Reminder body: loaded at fire time from `$REWARD_ANCHOR_FILE`, default
## `~/.claude/anchors/reward_anchor.md` (typically a symlink into a private
## prompts repo). The file is a template — `<MODE>` and `<COUNT>` are
## substituted at emit time so the reminder reflects the current run.
## Missing/unreadable file → silent no-op (same exit path as
## `ENABLE_REWARD_ANCHOR=0`) so a fresh machine without the prompts repo
## checked out doesn't break the hook. Keep the body under the 10K char
## `additionalContext` cap.

import std/[json, os, strutils, times]
import cligen

const defaultReminderRelPath = ".claude/anchors/reward_anchor.md"
const defaultFrequency = 8

const triggerTools = ["Edit", "Write", "MultiEdit", "Agent"]
const triggerModes = ["acceptEdits", "auto", "bypassPermissions"]

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

type State = object
  count: int
  lastFiredAt: string

# ---------------------------------------------------------------------------
# State file — nested under ~/.claude/reward_anchor/. saveState creates the
# parent dir lazily.
# ---------------------------------------------------------------------------

proc stateFilePath(sessionId: string): string =
  getHomeDir() / ".claude" / "reward_anchor" / (sessionId & ".json")

proc loadState(sessionId: string): State =
  let path = stateFilePath(sessionId)
  if not fileExists(path):
    return State()
  try:
    let j = parseJson(readFile(path))
    if j.kind == JObject:
      result.count = j{"count"}.getInt(0)
      result.lastFiredAt = j{"last_fired_at"}.getStr("")
  except JsonParsingError, ValueError, IOError, OSError:
    discard

proc saveState(sessionId: string, state: State) =
  let path = stateFilePath(sessionId)
  try:
    createDir(path.parentDir)
    var payload = %*{"count": state.count}
    if state.lastFiredAt.len > 0:
      payload["last_fired_at"] = %state.lastFiredAt
    writeFile(path, $payload)
  except IOError, OSError:
    discard

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

proc currentFrequency(): int =
  let raw = getEnv("REWARD_ANCHOR_FREQUENCY", "")
  if raw.len == 0:
    return defaultFrequency
  try:
    let n = parseInt(raw)
    if n > 0: n else: defaultFrequency
  except ValueError:
    defaultFrequency

proc disabled(): bool =
  getEnv("ENABLE_REWARD_ANCHOR", "1") == "0"

proc reminderPath(): string =
  let raw = getEnv("REWARD_ANCHOR_FILE", "")
  if raw.len > 0:
    return expandTilde(raw)
  return getHomeDir() / defaultReminderRelPath

proc loadReminder(): string =
  let path = reminderPath()
  if not fileExists(path):
    return ""
  try:
    return readFile(path)
  except IOError, OSError:
    return ""

proc inject(mode: string, count: int, tmpl: string) =
  let body = tmpl.replace("<MODE>", mode).replace("<COUNT>", $count)
  echo %*{
    "hookSpecificOutput":
      {"hookEventName": "PreToolUse", "additionalContext": body}
  }

proc readStdinPayload(): JsonNode =
  try:
    parseJson(stdin.readAll())
  except JsonParsingError, ValueError, IOError:
    nil

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

proc handlePretoolUse(data: JsonNode) =
  if disabled():
    return
  let toolName = data{"tool_name"}.getStr("")
  if toolName notin triggerTools:
    return
  let mode = data{"permission_mode"}.getStr("")
  if mode notin triggerModes:
    return
  let sessionId = data{"session_id"}.getStr("default")
  let freq = currentFrequency()
  var state = loadState(sessionId)
  state.count += 1
  let fires = state.count mod freq == 0
  if fires:
    state.lastFiredAt = $now().utc()
  saveState(sessionId, state)
  if fires:
    let tmpl = loadReminder()
    if tmpl.len > 0:
      inject(mode, state.count, tmpl)

proc handleReset(data: JsonNode) =
  if disabled():
    return
  let sessionId = data{"session_id"}.getStr("default")
  saveState(sessionId, State())

# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------

proc pretooluse() =
  ## PreToolUse — increment counter; inject reminder at threshold.
  let data = readStdinPayload()
  if data != nil:
    handlePretoolUse(data)

proc resetCounter() =
  ## UserPromptSubmit — zero the counter (new turn, new scope).
  ## Named `resetCounter` to avoid collision with `system.reset`.
  let data = readStdinPayload()
  if data != nil:
    handleReset(data)

when isMainModule:
  dispatchMulti(
    [pretooluse, cmdName = "pretooluse"], [resetCounter, cmdName = "reset"]
  )
