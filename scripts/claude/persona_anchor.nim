## Claude Code persona re-anchor hook — periodically re-injects a compressed
## recap of the user's CLAUDE.md to combat character/instruction drift over
## long agentic sessions. Inspired by SillyTavern's Author's Note (depth +
## frequency) and World Info Constant patterns.
##
## Subcommands (cligen dispatchMulti):
##   session-start  — SessionStart event. Always injects (matchers
##                    startup|resume|compact|clear all carry the recap).
##   prompt-submit  — UserPromptSubmit event. Counter-gated: injects only
##                    on every Nth call (default N=10).
##
## Output protocol:
##   - Fires: emits `hookSpecificOutput.additionalContext` envelope to
##     stdout. Both events officially carry `additionalContext`.
##   - Doesn't fire: silent (exit 0, no output) — counter not at threshold,
##     kill switch set, or stdin payload missing.
##
## Kill switch: `ENABLE_PERSONA_ANCHOR=0` → immediate exit 0, no output.
## Tuning:      `PERSONA_ANCHOR_FREQUENCY=N` → override default N=10 for
##              prompt-submit. session-start ignores this.
##
## State file: `~/.claude/persona_anchor/<session_id>.json`
##   Shape: `{"count": <int>, "last_fired_at": "<iso8601>"}`
##   `last_fired_at` is set only on actual fires (not on every increment).
##   Survives `--resume`/`--continue` because session_id is stable.
##   Parent dir is created lazily by `saveState` on first fire.
##
## Reminder body: loaded at fire time from `$PERSONA_ANCHOR_FILE`, default
## `~/.claude/anchors/persona_anchor.md` (typically a symlink into a private
## prompts repo). Missing/unreadable file → silent no-op (same exit path as
## `ENABLE_PERSONA_ANCHOR=0`) so a fresh machine without the prompts repo
## checked out doesn't break the hook. Keep the body under the 10K char
## `additionalContext` cap.

import std/[json, os, strutils, times]
import cligen

const defaultReminderRelPath = ".claude/anchors/persona_anchor.md"
const defaultFrequency = 10

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

type State = object
  count: int
  lastFiredAt: string

# ---------------------------------------------------------------------------
# State file — nested under ~/.claude/persona_anchor/ to keep the top level
# uncluttered. saveState creates the parent dir lazily.
# ---------------------------------------------------------------------------

proc stateFilePath(sessionId: string): string =
  getHomeDir() / ".claude" / "persona_anchor" / (sessionId & ".json")

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
  let raw = getEnv("PERSONA_ANCHOR_FREQUENCY", "")
  if raw.len == 0:
    return defaultFrequency
  try:
    let n = parseInt(raw)
    if n > 0: n else: defaultFrequency
  except ValueError:
    defaultFrequency

proc disabled(): bool =
  getEnv("ENABLE_PERSONA_ANCHOR", "1") == "0"

proc reminderPath(): string =
  let raw = getEnv("PERSONA_ANCHOR_FILE", "")
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

proc inject(eventName, body: string) =
  echo %*{
    "hookSpecificOutput":
      {"hookEventName": eventName, "additionalContext": body}
  }

proc readStdinPayload(): JsonNode =
  try:
    parseJson(stdin.readAll())
  except JsonParsingError, ValueError, IOError:
    nil

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

proc handleSessionStart(data: JsonNode) =
  if disabled():
    return
  let body = loadReminder()
  if body.len == 0:
    return
  inject("SessionStart", body)

proc handlePromptSubmit(data: JsonNode) =
  if disabled():
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
    let body = loadReminder()
    if body.len > 0:
      inject("UserPromptSubmit", body)

# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------

proc sessionStart() =
  ## SessionStart — always inject the recap (no counter gate).
  let data = readStdinPayload()
  if data != nil:
    handleSessionStart(data)

proc promptSubmit() =
  ## UserPromptSubmit — counter-gated; inject every Nth call.
  let data = readStdinPayload()
  if data != nil:
    handlePromptSubmit(data)

when isMainModule:
  dispatchMulti(
    [sessionStart, cmdName = "session-start"], [promptSubmit, cmdName = "prompt-submit"]
  )
