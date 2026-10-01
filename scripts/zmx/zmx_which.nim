## zmx-which — which zmx session is each Claude agent running in?
##
## The agent to zmx session association as a command. agent-sessions and
## mission-control get the same answer in-process from `resolveAgents()`; how
## an agent is matched is in `zmx_agents`.
##
## Schema per agent that has a pid:
##   { pid, kind, status, session_id, cwd, zmx_session, association_source,
##     clients, occ, turn_status, task_state, name, short_id, started }
##
## `status` is merged as in agent-sessions: an interactive agent's turn status,
## any other agent's task state. `turn_status` and `task_state` are Claude's
## `status` and `state` as sent. `occ` is the session's occupancy, not the
## agent's turn status.
##
## Built to ~/.local/bin/zmx-which by run_onchange_build-scripts.sh.tmpl.

import std/sequtils
import cligen
import zmx_agents, term_out

const Columns = ["PID", "KIND", "STATUS", "SESSION", "CL", "VIA", "NAME", "CWD"]

func toRow(agent: AgentSession, found: Option[Association]): WhichOut =
  result = WhichOut(
    pid: int(agent.pid.get),
    kind: agent.kind,
    status: effectiveStatus(agent),
    cwd: agent.cwd,
    turnStatus: agent.status,
    taskState: agent.state,
    name: agent.name,
    shortId: agent.shortId,
    started: agent.startedAt.get(0),
  )
  if agent.sessionId.isSome:
    result.sessionId = some($agent.sessionId.get)
  if found.isSome:
    result.zmxSession = some($found.get.session)
    result.associationSource = some(found.get.source)

func orDash(cell: Option[string]): string =
  ## An absent value is a dim `-`.
  if cell.isSome:
    cell.get
  else:
    paint(Dim, "-")

func cells(row: WhichOut): seq[string] =
  let color =
    case turnStatusOf(row.status)
    of asWaiting: Red
    of asBusy: Yellow
    else: Dim
  @[
    $row.pid,
    orDash(row.kind),
    paint(color, row.status),
    orDash(row.zmxSession),
    (if row.clients.isSome: $row.clients.get else: paint(Dim, "-")),
    (if row.associationSource.isSome: $row.associationSource.get
    else: paint(Dim, "-")),
    paint(Dim, clip(row.name.get("-"), NameWidth)),
    paint(Dim, row.cwd.get("")),
  ]

proc zmxWhich(json = false, target: seq[string]): int =
  ## Which zmx session each Claude agent runs in, and how that was found.
  ##
  ## association_source is the first that answered:
  ##   label         the session's claude_session label equals the agent's id
  ##   process_env   ZMX_SESSION in the agent's exec-time environment
  ##   process_tree  the agent's pid is a descendant of the session daemon
  ##
  ## --json prints, per agent that has a pid:
  ##   { pid, kind, status, session_id, cwd, zmx_session, association_source,
  ##     clients, occ, turn_status, task_state, name, short_id, started }
  ## status is an interactive agent's turn status and any other agent's task
  ## state; turn_status and task_state are Claude's own two fields. occ is the
  ## session's occupancy (active|idle), not the agent's turn status.
  if target.len > 1:
    stderr.writeLine "zmx-which: one session or pid at most (see --help)"
    return 2
  let filter =
    if target.len == 1:
      target[0]
    else:
      ""

  let resolved = resolveAgents()
  for problem in resolved.problems:
    stderr.writeLine "zmx-which: " & problem

  var rows: seq[WhichOut]
  for i, agent in resolved.agents:
    if agent.pid.isNone:
      continue
    var row = toRow(agent, resolved.found[i])
    if resolved.found[i].isSome:
      let view = resolved.viewOf(resolved.found[i].get.session)
      if view.isSome:
        row.clients = some(view.get.session.clients)
        row.occ = some(view.get.state)
    if filter.len == 0 or row.zmxSession == some(filter) or $row.pid == filter:
      rows.add row

  if json:
    echo ZmxJson.encode(rows, pretty = true)
    return 0

  for line in layout(@[Columns.mapIt(paint(Bold, it))] & rows.map(cells)):
    echo line
  0

when isMainModule:
  cgParseErrorExitCode = 2
  clCfg.longPfxOk = false
  dispatch zmxWhich,
    cmdName = "zmx-which",
    short = {"json": '\0'},
    help = {
      "json": "one JSON object per agent instead of the table",
      "target": "[session|pid]",
    }
