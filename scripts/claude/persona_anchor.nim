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
##   resolve        — prints the anchor path that WOULD be injected, for
##                    hosts with no hook system:
##                      lu --system-prompt-file "$(persona-anchor resolve --agent lu)"
##                    Exits 1 with no output when nothing resolves.
##
## `--agent <slug>` names the host agent for manifest matching. Each agent's
## hook config is agent-specific by construction, so the caller knows; the
## env-sniffing `agentSlug()` is only the fallback (`CODEX_SANDBOX` is set
## only when Codex's sandbox is active, so sniffing can't be trusted).
##
## Output protocol:
##   - Fires: emits `hookSpecificOutput.additionalContext` envelope to
##     stdout. Both events officially carry `additionalContext`.
##   - Doesn't fire: silent (exit 0, no output) — counter not at threshold,
##     kill switch set, stdin payload missing, or no anchor resolved.
##
## Kill switch: `ENABLE_PERSONA_ANCHOR=0` → immediate exit 0, no output.
## Tuning:      `PERSONA_ANCHOR_FREQUENCY=N` → override default N=10 for
##              prompt-submit. session-start ignores this.
##
## State file: `~/.claude/persona_anchor/<session_id>.json` — see
## `scripts/lib/anchor.nim`. The counter increments on every prompt-submit
## whether or not a body resolves, so a `skip = true` directory can't
## desynchronize the every-Nth cadence when you move back out of it.
##
## Reminder body: chosen at fire time by `resolveAnchor` — `$PERSONA_ANCHOR_FILE`,
## then the manifest (`~/.claude/anchors/anchors.toml`), then the legacy
## `~/.claude/anchors/persona_anchor.md`. All of these are typically symlinks
## into a private prompts repo; a fresh machine without it checked out
## resolves to nothing and no-ops. Keep the body under the 10K char
## `additionalContext` cap.

import std/[json, os, times]
import cligen
import ../lib/agent_env
import ../lib/anchor

const
  kind = "persona"
  envVar = "PERSONA_ANCHOR_FILE"
  legacyRelPath = ".claude/anchors/persona_anchor.md"
  stateDir = "persona_anchor"
  defaultFrequency = 10

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

proc sessionStart(agent = "") =
  ## SessionStart — always inject the recap (no counter gate).
  if disabled("ENABLE_PERSONA_ANCHOR"):
    return
  let data = readStdinPayload()
  if data == nil:
    return
  let body = bodyFor(data, agent)
  if body.len > 0:
    inject("SessionStart", body)

proc promptSubmit(agent = "") =
  ## UserPromptSubmit — counter-gated; inject every Nth call.
  if disabled("ENABLE_PERSONA_ANCHOR"):
    return
  let data = readStdinPayload()
  if data == nil:
    return
  let
    sessionId = data{"session_id"}.getStr("default")
    freq = currentFrequency("PERSONA_ANCHOR_FREQUENCY", defaultFrequency)
  var state = loadState(stateDir, sessionId)
  state.count += 1
  let fires = state.count mod freq == 0
  if fires:
    state.lastFiredAt = $now().utc()
  saveState(stateDir, sessionId, state)
  if fires:
    let body = bodyFor(data, agent)
    if body.len > 0:
      inject("UserPromptSubmit", body)

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
    [sessionStart, cmdName = "session-start"],
    [promptSubmit, cmdName = "prompt-submit"],
    [resolve, cmdName = "resolve"],
  )
