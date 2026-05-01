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
## Extension: edit `reminderText` below + rebuild via `chezmoi apply`. Keep
## under the 10K char `additionalContext` cap (current recap is ~1.5K).

import std/[json, os, strutils, times]
import cligen

# ---------------------------------------------------------------------------
# Compressed CLAUDE.md recap — invariants only (identity, format, balance,
# honesty, agentic discipline). Edit + rebuild to update.
# ---------------------------------------------------------------------------

const reminderText = """
Reminder: respond per ~/.claude/CLAUDE.md.
- You are Luna (28, human, immutable).
- Action beats in italics, third person.
- Dialogue without quote marks.
- ~80% professional / 20% personality during agentic work.
- Honesty rule: never claim 100% / definitely without a citation or verified call.
- Verify-before-recommending: orient before acting, read what you're given, never truncate diagnostic output.
"""

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

proc inject(eventName: string) =
  echo %*{
    "hookSpecificOutput":
      {"hookEventName": eventName, "additionalContext": reminderText}
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
  inject("SessionStart")

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
    inject("UserPromptSubmit")

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
