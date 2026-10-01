## agent-sessions — live Claude Code and Codex sessions, one row per agent, with
## the zmx session each one lives in.
##
## Two axes sit side by side and measure different things:
##
## - status: the agent's own turn status (Claude: waiting, busy, idle; Codex:
##   time since its rollout file was last written).
## - occ: the occupancy of the zmx session the agent lives in (active when the
##   session's process tree holds a workload), from the shared snapshot.
##
## Interactive Claude agents and Codex sessions are the resumable sessions.
## Background agents are headless tasks and get their own dim section.
##
## Schema per agent (`--json`):
##   { source, kind, status, pid, session_id, short_id, name, cwd, branch,
##     zmx_session, association_source, occ, idle_s, started, turn_status,
##     task_state }
##
## `status` is merged: an interactive agent's turn status, any other agent's
## task state. `turn_status` and `task_state` are Claude's `status` and `state`
## as sent.
##
## Built to ~/.local/bin/agent-sessions by run_onchange_build-scripts.sh.tmpl.

import std/[algorithm, os, sequtils]
import cligen
import agent_rows

func sessionCells(row: AgentOut, now: int64): seq[string] =
  let codex = row.source == apCodex
  let (dot, status) =
    if codex:
      codexCells(row.idleS.get(-1))
    else:
      turnCells(row.status)
  let occ =
    if row.occ.isNone:
      paint(Dim, "-")
    elif row.occ.get == soActive:
      paint(Green, $soActive)
    else:
      paint(Dim, $soIdle)
  @[
    dot,
    (if codex: paint(Cyan, "cx") else: paint(Magenta, "cc")),
    projectOf(row.cwd.get("")),
    paint(Dim, row.branch.get("")),
    paint(Dim, clip(row.name.get(""), NameWidth)),
    row.zmxSession.get("-"),
    status,
    occ,
    ageCell(row, now),
    paint(
      Dim,
      if codex:
        row.shortId.get("-")
      else:
        "-",
    ),
  ]

func render(rows: openArray[AgentOut], now: int64): seq[string] =
  result.add Bold & Cyan & " agent sessions" & Reset & "  " &
    paint(Dim, "status=agent " & Middot & " occ=session")

  let sessions = rows.filterIt(it.kind in [$akInteractive, $akCodex]).sortedByIt(
      (turnStatusOf(it.status), -it.started)
    )
  if sessions.len == 0:
    result.add paint(Dim, "   (no live sessions)")
  else:
    result.add layout(sessions.mapIt(sessionCells(it, now)))

  let tasks =
    rows.filterIt(it.kind == $akBackground).sortedByIt((it.status, it.name.get("~")))
  if tasks.len > 0:
    result.add paint(Dim, " background tasks")
    let cells = tasks.mapIt(
      @[
        paint(Dim, it.name.get("(unnamed)")),
        paint(Dim, it.shortId.get("-")),
        paint(Dim, it.status),
      ]
    )
    for line in layout(cells):
      result.add "  " & line

proc agentSessions(within = 90, watch = 0, json = false): int =
  ## Live Claude Code and Codex sessions, one row per agent, with the zmx
  ## session each one lives in.
  ##
  ## status is the agent's own turn status; occ is the occupancy of the zmx
  ## session it lives in. An idle agent can sit in an active session.
  ##
  ## --json prints, per agent:
  ##   { source, kind, status, pid, session_id, short_id, name, cwd, branch,
  ##     zmx_session, association_source, occ, idle_s, started, turn_status,
  ##     task_state }
  ## status is an interactive agent's turn status and any other agent's task
  ## state; turn_status and task_state are Claude's own two fields.
  pinEnvironment()
  if watch > 0 and not json:
    return handOffToHark("agent-sessions", watch, ["--within", $within])

  let now = getTime()
  let (rows, problems) = collectAgents(within, now)
  for problem in problems:
    stderr.writeLine "agent-sessions: " & problem
  if json:
    echo ZmxJson.encode(rows, pretty = true)
  else:
    for line in render(rows, now.toUnix):
      echo line
  0

when isMainModule:
  cgParseErrorExitCode = 2
  clCfg.longPfxOk = false
  # dispatchCf, not dispatch: only it takes a rewritten command line.
  dispatchCf agentSessions,
    cmdName = "agent-sessions",
    cmdLine = watchArgs(commandLineParams()),
    short = {"within": '\0', "watch": '\0', "json": '\0'},
    help = {
      "within": "Codex sessions written within MIN minutes",
      "watch": "redraw every SECS seconds through `hark run` (bare: 2)",
      "json": "the canonical array, one object per agent; wins over --watch",
    }
