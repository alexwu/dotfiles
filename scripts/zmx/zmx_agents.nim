## Claude's running agents, and which zmx session each one lives in.
##
## An agent is matched to a session by the first source that answers:
##
## - `asLabel`: a session labelled `agent=claude` carries a `claude_session`
##   label equal to the agent's session id (`zmx-agent-label` sets it from
##   Claude's `SessionStart` hook).
## - `asProcessEnv`: `ZMX_SESSION` in the agent's exec-time environment.
## - `asProcessTree`: the agent's pid is a descendant of the session daemon.
##
## A label left behind by a crashed agent equals no live session id, so it is
## never matched.

import std/[osproc, strutils]
import zmx_snapshot

export zmx_snapshot

type
  Association* = object
    session*: ZmxSessionName
    source*: AssociationSource

  EnvLookup* = proc(pid: ProcessId): Option[string]
    ## The value of `ZMX_SESSION` in a process's environment.

func toAgent(a: ClaudeAgentIn): AgentSession =
  result = AgentSession(
    kind: a.kind, status: (if a.status.isSome: a.status else: a.state), cwd: a.cwd
  )
  if a.pid.isSome:
    result.pid = some(ProcessId(a.pid.get))
  if a.sessionId.isSome:
    result.sessionId = some(ClaudeSessionId(a.sessionId.get))

proc decodeAgents*(text: string): Result[seq[AgentSession], string] =
  ## The output of `claude agents --json`. Blank output is no agents.
  if text.isEmptyOrWhitespace:
    return ok(newSeq[AgentSession]())
  try:
    var agents: seq[AgentSession]
    for entry in ClaudeJson.decode(text, seq[ClaudeAgentIn]):
      agents.add toAgent(entry)
    ok(agents)
  except SerializationError as e:
    err("could not read `claude agents --json`: " & e.msg)

proc listAgents*(): Result[seq[AgentSession], string] =
  pinEnvironment()
  try:
    # The exit code is not consulted: whatever JSON arrived is the answer.
    let (output, _) = execCmdEx("claude agents --json", options = {poUsePath})
    decodeAgents(output)
  except OSError, IOError:
    err("could not run `claude agents`: " & getCurrentExceptionMsg())

proc associate*(
    agents: openArray[AgentSession], views: openArray[SessionView], zmxEnv: EnvLookup
): seq[Option[Association]] =
  ## One entry per agent, in order. `zmxEnv` is asked only about agents no
  ## label claims.
  var byLabel: Table[string, ZmxSessionName]
  var byPid: Table[int, ZmxSessionName]
  for view in views:
    let labels = view.session.labels
    if labels.getOrDefault("agent") == "claude" and "claude_session" in labels:
      # Two sessions claiming one id: the later in `zmx list` order wins.
      byLabel[labels["claude_session"]] = view.session.name
    for p in view.procs:
      byPid[int(p.pid)] = view.session.name

  for agent in agents:
    var found = none(Association)
    if agent.sessionId.isSome and $agent.sessionId.get in byLabel:
      found = some(Association(session: byLabel[$agent.sessionId.get], source: asLabel))
    elif agent.pid.isSome:
      let named = zmxEnv(agent.pid.get)
      if named.isSome:
        found =
          some(Association(session: ZmxSessionName(named.get), source: asProcessEnv))
      elif int(agent.pid.get) in byPid:
        found =
          some(Association(session: byPid[int(agent.pid.get)], source: asProcessTree))
    result.add found
