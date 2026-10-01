## zmx-which — which zmx session is each Claude agent running in?
##
## The one place that associates `claude agents --json` entries with zmx
## sessions; agent-sessions and mission-control read its --json. How an agent
## is matched is in `zmx_agents`.
##
## Schema per agent that has a pid:
##   { pid, kind, status, session_id, cwd, zmx_session, association_source,
##     clients, occ }
##
## `occ` is the session's occupancy, not the agent's turn status.
##
## Built to ~/.local/bin/zmx-which by run_onchange_build-scripts.sh.tmpl.

import std/[os, osproc, sequtils, streams, strutils]
import cligen
import zmx_agents

const Columns = ["PID", "KIND", "STATUS", "SESSION", "CL", "VIA", "CWD"]

func toRow(agent: AgentSession, found: Option[Association]): WhichOut =
  result = WhichOut(
    pid: int(agent.pid.get), kind: agent.kind, status: agent.status, cwd: agent.cwd
  )
  if agent.sessionId.isSome:
    result.sessionId = some($agent.sessionId.get)
  if found.isSome:
    result.zmxSession = some($found.get.session)
    result.associationSource = some(found.get.source)

func cells(row: WhichOut): seq[string] =
  @[
    $row.pid,
    row.kind.get("-"),
    row.status.get("?"),
    row.zmxSession.get("-"),
    (if row.clients.isSome: $row.clients.get else: "-"),
    (if row.associationSource.isSome: $row.associationSource.get
    else: "-"),
    row.cwd.get(""),
  ]

proc gumTable(table: seq[seq[string]]): bool =
  ## Renders through `gum table`. False when gum is missing or rejects the
  ## rows, and then nothing has been printed.
  if findExe("gum").len == 0:
    return false
  try:
    let gum = startProcess(
      "gum",
      args = [
        "table",
        "--print",
        "--lazy-quotes",
        "--separator",
        "\t",
        "--columns",
        Columns.join(","),
      ],
      options = {poUsePath},
    )
    defer:
      gum.close()
    for row in table:
      gum.inputStream.writeLine row.join("\t")
    gum.inputStream.close()
    let rendered = gum.outputStream.readAll()
    if gum.waitForExit() != 0:
      return false
    stdout.write rendered
    true
  except OSError, IOError:
    false

proc plainTable(table: seq[seq[string]]) =
  var widths = Columns.mapIt(it.len)
  for row in table:
    for i, cell in row:
      widths[i] = max(widths[i], cell.len)
  for row in @[@Columns] & table:
    var line = ""
    for i, cell in row:
      line.add (if i == row.high: cell else: alignLeft(cell, widths[i] + 2))
    echo line

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
  ##     clients, occ }
  ## occ is the session's occupancy (active|idle), not the agent's turn status.
  if target.len > 1:
    stderr.writeLine "zmx-which: one session or pid at most (see --help)"
    return 2
  let filter =
    if target.len == 1:
      target[0]
    else:
      ""

  # A failed read is no sessions or no agents, as it was for the Bash version:
  # the readers treat an empty listing as nothing to show.
  let views = snapshot().valueOr:
    stderr.writeLine "zmx-which: " & error
    newSeq[SessionView]()
  let agents = listAgents().valueOr:
    stderr.writeLine "zmx-which: " & error
    newSeq[AgentSession]()

  let source = procSource()
  let found = associate(
    agents,
    views,
    proc(pid: ProcessId): Option[string] =
      readEnvVar(source, pid, "ZMX_SESSION"),
  )

  var rows: seq[WhichOut]
  for i, agent in agents:
    if agent.pid.isNone:
      continue
    var row = toRow(agent, found[i])
    if found[i].isSome:
      for view in views:
        if view.session.name == found[i].get.session:
          row.clients = some(view.session.clients)
          row.occ = some(view.state)
    if filter.len == 0 or row.zmxSession == some(filter) or $row.pid == filter:
      rows.add row

  if json:
    echo ZmxJson.encode(rows, pretty = true)
    return 0

  let table = rows.map(cells)
  if table.len == 0 or not gumTable(table):
    plainTable(table)
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
