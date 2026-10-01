## What `agent-sessions` and `mission-control` share: the canonical agent rows,
## their status cells, and the `--watch` handoff to `hark run`.

import std/[os, strutils]
from std/posix import execv, strerror, errno
import zmx_agents, codex_sessions, git_head, term_out

export zmx_agents, codex_sessions, git_head, term_out

const FreshS* = 20 ## a Codex session written this recently counts as working

type BranchLookup* = proc(dir: string): Option[string]

func fmtIdle*(seconds: int64): string =
  ## `45s`, `12m`, `3h4m`.
  if seconds < 60:
    $seconds & "s"
  elif seconds < 3600:
    $(seconds div 60) & "m"
  else:
    $(seconds div 3600) & "h" & $(seconds mod 3600 div 60) & "m"

func projectOf*(cwd: string): string =
  ## The directory's last component; `?` when there is no directory.
  if cwd.len == 0:
    return "?"
  result = cwd.lastPathPart
  if result.len == 0:
    result = cwd

func turnCells*(status: string): tuple[dot, text: string] =
  ## A Claude agent's dot and status cell. Anything but waiting or busy reads
  ## as idle.
  case turnStatusOf(status)
  of asWaiting:
    (paint(Red & Bold, DotFull), paint(Red, "waiting"))
  of asBusy:
    (paint(Yellow, DotFull), paint(Yellow, "busy"))
  else:
    (paint(Dim, DotHollow), paint(Dim, "idle"))

func codexCells*(idleS: int64): tuple[dot, text: string] =
  ## A Codex session's dot and status cell: how long since it last wrote.
  if idleS < 0: # the clock moved under us
    (paint(Dim, DotHollow), paint(Dim, "idle"))
  elif idleS < FreshS:
    (paint(Green, DotFull), paint(Dim, fmtIdle(idleS)))
  else:
    (paint(Dim, DotHollow), paint(Dim, fmtIdle(idleS)))

func nonEmpty(s: Option[string]): Option[string] =
  if s.isSome and s.get.len > 0:
    result = s

proc claudeRows*(r: Resolved, branch: BranchLookup): seq[AgentOut] =
  ## One row per Claude agent, in Claude's order. The zmx session and its
  ## occupancy are filled for every agent that has a pid.
  for i, agent in r.agents:
    var row = AgentOut(
      source: apClaude,
      kind: agent.kind.get(""),
      status: effectiveStatus(agent),
      shortId: nonEmpty(agent.shortId),
      name: nonEmpty(agent.name),
      cwd: nonEmpty(agent.cwd),
      started: agent.startedAt.get(0),
    )
    if agent.sessionId.isSome and len($agent.sessionId.get) > 0:
      row.sessionId = some($agent.sessionId.get)
    if row.cwd.isSome:
      row.branch = nonEmpty(branch(row.cwd.get))
    if agent.pid.isSome:
      row.pid = some(int(agent.pid.get))
      if r.found[i].isSome:
        row.zmxSession = some($r.found[i].get.session)
        row.associationSource = some(r.found[i].get.source)
        let view = r.viewOf(r.found[i].get.session)
        if view.isSome:
          row.occ = some(view.get.state)
    result.add row

func codexRows*(sessions: openArray[CodexSession], now: int64): seq[AgentOut] =
  ## One row per Codex session, in the order given. Codex reports no turn
  ## status, so `status` is `idle` and `idle_s` is the time since its last write.
  for session in sessions:
    var row = AgentOut(
      source: apCodex,
      kind: $akCodex,
      status: $asIdle,
      cwd: session.cwd,
      branch: session.branch,
      idleS: some(now - session.modified),
      started: session.modified,
    )
    if session.id.isSome:
      let id = $session.id.get
      row.sessionId = some(id)
      if id.len > 0:
        row.shortId = some(id[0 ..< min(8, id.len)])
    result.add row

proc collectAgents*(
    withinMin: int, now: Time
): tuple[rows: seq[AgentOut], problems: seq[string]] =
  ## Claude's agents, then Codex sessions written within `withinMin` minutes,
  ## newest first.
  let resolved = resolveAgents()
  result.problems = resolved.problems
  result.rows = claudeRows(resolved, branchOf)
  result.rows.add codexRows(
    recentCodexSessions(getHomeDir() / ".codex/sessions", withinMin, now), now.toUnix
  )

func watchArgs*(args: openArray[string]): seq[string] =
  ## Lets `--watch` take an optional value: `--watch 5` becomes `--watch=5`, and
  ## a bare `--watch` becomes `--watch=2`.
  var i = 0
  while i < args.len:
    if args[i] != "--watch":
      result.add args[i]
      inc i
    elif i + 1 < args.len and args[i + 1].len > 0 and args[i + 1].allCharsInSet(Digits):
      result.add "--watch=" & args[i + 1]
      i += 2
    else:
      result.add "--watch=2"
      inc i

proc handOffToHark*(tool: string, watch: int, args: openArray[string]): int =
  ## Replaces this process with `hark run -e <watch>s -- <this binary> <args>`.
  ## Returns only when that could not happen, with the exit code to use.
  var hark = findExe("hark")
  if hark.len == 0:
    # cargo's bin directory is not on the pinned PATH.
    let cargo = getHomeDir() / ".cargo/bin/hark"
    if fileExists(cargo):
      hark = cargo
  if hark.len == 0:
    stderr.writeLine tool & ": --watch needs hark on PATH"
    return 1
  let argv = allocCStringArray(
    @[hark, "run", "-e", $watch & "s", "--", getAppFilename()] & @args
  )
  discard execv(hark.cstring, argv)
  deallocCStringArray(argv)
  stderr.writeLine tool & ": could not run hark: " & $strerror(errno)
  1
