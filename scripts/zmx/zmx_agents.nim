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

  Resolved* = object
    ## Every session, every agent, and where each agent lives. `agents` and
    ## `found` run in step.
    views*: seq[SessionView]
    agents*: seq[AgentSession]
    found*: seq[Option[Association]]
    problems*: seq[string] ## why `views` or `agents` came back empty

func toAgent(a: ClaudeAgentIn): AgentSession =
  result = AgentSession(
    kind: a.kind,
    status: a.status,
    state: a.state,
    shortId: a.id,
    name: a.name,
    cwd: a.cwd,
  )
  if a.pid.isSome:
    result.pid = some(ProcessId(a.pid.get))
  if a.sessionId.isSome:
    result.sessionId = some(ClaudeSessionId(a.sessionId.get))
  if a.startedAt.isSome:
    result.startedAt = some(a.startedAt.get div 1000)

func kindOf*(a: AgentSession): AgentKind =
  ## `interactive` and `background` by name; anything else is `akOther`.
  case a.kind.get("")
  of "interactive": akInteractive
  of "background": akBackground
  else: akOther

func turnStatusOf*(raw: string): AgentStatus =
  ## `waiting`, `busy`, `idle`; anything else is `asOther`.
  case raw
  of "waiting": asWaiting
  of "busy": asBusy
  of "idle": asIdle
  else: asOther

func whichStatus*(a: AgentSession): Option[string] =
  ## What `zmx-which` reports: `status`, or a background agent's `state`.
  if a.status.isSome: a.status else: a.state

func effectiveStatus*(a: AgentSession): string =
  ## What `agent-sessions` reports: the turn status of an interactive agent
  ## (`idle` when absent), the task state of any other (`?` when absent).
  let (raw, fallback) =
    if kindOf(a) == akInteractive:
      (a.status.get(""), "idle")
    else:
      (a.state.get(""), "?")
  if raw.len > 0: raw else: fallback

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

proc resolveAgents*(): Resolved =
  ## A failed read leaves its list empty and says why in `problems`: the tools
  ## treat an empty listing as nothing to show.
  pinEnvironment()
  result.views = snapshot().valueOr:
    result.problems.add error
    newSeq[SessionView]()
  result.agents = listAgents().valueOr:
    result.problems.add error
    newSeq[AgentSession]()
  let source = procSource()
  result.found = associate(
    result.agents,
    result.views,
    proc(pid: ProcessId): Option[string] =
      readEnvVar(source, pid, "ZMX_SESSION"),
  )

func viewOf*(r: Resolved, name: ZmxSessionName): Option[SessionView] =
  for view in r.views:
    if view.session.name == name:
      return some(view)
