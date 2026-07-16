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
##   reset       — UserPromptSubmit. Zeros the per-turn counter so `<COUNT>`
##                 stays "edits since Alex's last prompt" (scope creep is
##                 per-turn). A reset landing on a nonzero count also bumps
##                 the session `<TURNS>` tally — how many climbs he's
##                 interrupted this session; that one is NOT zeroed.
##   resolve     — prints the anchor path that WOULD be injected, for hosts
##                 with no hook system. Exits 1 with no output when nothing
##                 resolves (including a manifest `skip = true` match).
##
## `--agent <slug>` names the host agent for manifest matching; see
## `persona_anchor.nim` for why sniffing the env is only the fallback.
##
## Output protocol:
##   - Fires: emits `additionalContext` (no `permissionDecision`) — the
##     reminder rides alongside the tool result without altering the
##     permission flow. PreToolUse accepts additionalContext on its own.
##   - Doesn't fire: silent (exit 0, no output) — wrong tool, wrong mode,
##     counter not at threshold, kill switch set, stdin payload missing, or
##     no anchor resolved.
##
## Kill switch: `ENABLE_REWARD_ANCHOR=0` → immediate exit 0, no output.
## Tuning:      `REWARD_ANCHOR_FREQUENCY=N` → override default N=8.
##
## State file: `~/.claude/reward_anchor/<session_id>.json` — see
## `scripts/lib/anchor.nim`. No cleanup hook for now; files are tiny.
##
## Reminder body: chosen at fire time by `resolveAnchor` — `$REWARD_ANCHOR_FILE`,
## then the manifest (`~/.claude/anchors/anchors.toml`), then the legacy
## `~/.claude/anchors/reward_anchor.md`. The body is a template: `<MODE>`,
## `<COUNT>`, and `<TURNS>` are substituted at emit time so the reminder
## reflects the current run. Nothing resolved → silent no-op, so a fresh machine without the
## prompts repo checked out doesn't break the hook. Keep the body under the
## 10K char `additionalContext` cap.

import std/[json, os, times]
import cligen
import ../lib/agent_env
import ../lib/anchor

const
  kind = "reward"
  envVar = "REWARD_ANCHOR_FILE"
  legacyRelPath = ".claude/anchors/reward_anchor.md"
  stateDir = "reward_anchor"
  defaultFrequency = 8

  triggerTools = ["Edit", "Write", "MultiEdit", "Agent"]
  triggerModes = ["acceptEdits", "auto", "bypassPermissions"]

proc bodyFor(data: JsonNode, agentOverride: string): string =
  ## "" means "inject nothing" — missing file, `skip = true`, or no match.
  let
    cwd = data{"cwd"}.getStr(getCurrentDir())
    who =
      if agentOverride.len > 0:
        agentOverride
      else:
        agentSlug()
    r = resolveAnchor(kind, envVar, legacyRelPath, cwd, who)
  if r.skip or r.path.len == 0:
    ""
  else:
    loadReminder(r.path)

proc pretooluse(agent = "") =
  ## PreToolUse — increment counter; inject reminder at threshold.
  if disabled("ENABLE_REWARD_ANCHOR"):
    return
  let data = readStdinPayload()
  if data == nil:
    return
  let toolName = data{"tool_name"}.getStr("")
  if toolName notin triggerTools:
    return
  let mode = data{"permission_mode"}.getStr("")
  if mode notin triggerModes:
    return
  let
    sessionId = data{"session_id"}.getStr("default")
    freq = currentFrequency("REWARD_ANCHOR_FREQUENCY", defaultFrequency)
  var state = loadState(stateDir, sessionId)
  state.count += 1
  let fires = state.count mod freq == 0
  if fires:
    state.lastFiredAt = $now().utc()
  saveState(stateDir, sessionId, state)
  if fires:
    let body = bodyFor(data, agent)
    if body.len > 0:
      inject(
        "PreToolUse",
        applyTemplate(
          body, {"<MODE>": mode, "<COUNT>": $state.count, "<TURNS>": $state.resets}
        ),
      )

proc resetCounter() =
  ## UserPromptSubmit — zero the per-turn counter (new turn, new scope) while
  ## keeping the session tallies. A reset landing on a nonzero `count` bumps
  ## `resets` — the number of climbs he's interrupted mid-stride this session.
  ## Named `resetCounter` to avoid collision with `system.reset`.
  if disabled("ENABLE_REWARD_ANCHOR"):
    return
  let data = readStdinPayload()
  if data == nil:
    return
  let sessionId = data{"session_id"}.getStr("default")
  var state = loadState(stateDir, sessionId)
  if state.count > 0:
    state.resets += 1
  state.count = 0
  saveState(stateDir, sessionId, state)

proc resolve(agent = "", cwd = "") =
  ## Print the resolved anchor path; exit 1 with no output when none/skipped.
  let
    who =
      if agent.len > 0:
        agent
      else:
        agentSlug()
    where =
      if cwd.len > 0:
        cwd
      else:
        getCurrentDir()
    r = resolveAnchor(kind, envVar, legacyRelPath, where, who)
  if r.skip or r.path.len == 0:
    quit(1)
  echo r.path

when isMainModule:
  dispatchMulti(
    [pretooluse, cmdName = "pretooluse"],
    [resetCounter, cmdName = "reset"],
    [resolve, cmdName = "resolve"],
  )
