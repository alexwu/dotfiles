## mission-control — everything alive at a glance: Claude and Codex agents, the
## zmx sessions that host no agent, and the WezTerm workspace of each
## directory. Agents waiting on you sort to the top.
##
## Rows, in order:
##
## - `cc`: a Claude agent with a live process, waiting, then busy, then the rest.
##   Its name follows the branch, and its last column is the zmx session it
##   lives in.
## - `cx`: a Codex session whose rollout file was written recently.
## - `zmx`: a session hosting no listed agent, `shell` when a client is
##   attached and `detached` otherwise.
##
## Built to ~/.local/bin/mission-control by run_onchange_build-scripts.sh.tmpl.

import std/[algorithm, monotimes, os, osproc, sets, streams, strutils]
import cligen
import agent_rows

const WeztermDeadlineMs = 400

type
  Row = object
    priority: int
    recency: int64 ## epoch seconds; newer sorts first within a priority
    dir: string
    cells: seq[string]

  Wezterm = object
    process: Process
    started: MonoTime

proc startWezterm(): Option[Wezterm] =
  ## `wezterm cli list`, started early so it runs while the agents are read.
  if findExe("wezterm").len == 0:
    return
  try:
    let process = startProcess(
      "wezterm", args = ["cli", "list", "--format", "json"], options = {poUsePath}
    )
    result = some(Wezterm(process: process, started: getMonoTime()))
  except OSError:
    discard

proc workspaces(started: Option[Wezterm]): Table[string, string] =
  ## Directory to WezTerm workspace, the first pane seen winning. Decoration
  ## only: with WezTerm closed `wezterm cli list` hangs for seconds, so it gets
  ## a deadline counted from its start, and any failure is no tags.
  if started.isNone:
    return
  let wezterm = started.get.process
  try:
    defer:
      wezterm.close()
    let spent = int((getMonoTime() - started.get.started).inMilliseconds)
    # waitForExit kills and reaps the child itself when the deadline passes.
    if wezterm.waitForExit(max(1, WeztermDeadlineMs - spent)) != 0:
      return
    for pane in ClaudeJson.decode(wezterm.outputStream.readAll(), seq[WeztermPaneIn]):
      if pane.cwd.isSome and pane.workspace.isSome:
        let dir = decodeCwd(pane.cwd.get)
        if dir.len > 0 and dir notin result:
          result[dir] = pane.workspace.get
  except OSError, IOError, SerializationError:
    discard

func cells(
    dot, tag, dir, branch, name, status, host: string, tags: Table[string, string]
): seq[string] =
  var key = dir
  if key.len > 1:
    key.removeSuffix('/')
  @[
    dot,
    tag,
    projectOf(dir),
    paint(Dim, branch),
    paint(Dim, clip(name, NameWidth)),
    status,
    paint(Dim, host),
    (if key in tags: paint(Dim, Middot & tags[key]) else: ""),
  ]

proc collect(
    resolved: Resolved, within: int, now: Time, tags: Table[string, string]
): seq[Row] =
  var hosted: HashSet[string]
  for i, agent in resolved.agents:
    if agent.pid.isNone:
      continue
    let status = agent.status.get("")
    let dir = agent.cwd.get("")
    var host = ""
    if resolved.found[i].isSome:
      host = $resolved.found[i].get.session
      hosted.incl host
    let (dot, text) = turnCells(status)
    result.add Row(
      priority:
        case turnStatusOf(status)
        of asWaiting: 0
        of asBusy: 1
        else: 3
      ,
      recency: now.toUnix,
      dir: dir,
      cells: cells(
        dot,
        paint(Magenta, "cc"),
        dir,
        branchOf(dir).get(""),
        agent.name.get(""),
        text,
        host,
        tags,
      ),
    )

  for session in recentCodexSessions(getHomeDir() / ".codex/sessions", within, now):
    let dir = session.cwd.get("")
    let (dot, text) = codexCells(now.toUnix - session.modified)
    result.add Row(
      priority: 2,
      recency: session.modified,
      dir: dir,
      cells:
        cells(dot, paint(Cyan, "cx"), dir, session.branch.get(""), "", text, "", tags),
    )

  for view in resolved.views:
    let name = $view.session.name
    if name in hosted:
      continue
    let detached = view.session.clients == 0
    result.add Row(
      priority: if detached: 5 else: 4,
      recency: now.toUnix,
      dir: view.session.cwd,
      cells: cells(
        (if detached: paint(Dim, DotSmall) else: paint(Blue, DotFull)),
        paint(Blue, "zmx"),
        view.session.cwd,
        "",
        "",
        (if detached: paint(Dim, "detached") else: paint(Blue, "shell")),
        name,
        tags,
      ),
    )

proc missionControl(within = 90, watch = 0): int =
  ## Everything alive at a glance: Claude agents (cc), Codex sessions (cx) and
  ## the zmx sessions hosting neither (zmx), with agents waiting on you first.
  ##
  ## The column after the status is the zmx session a row lives in; a trailing
  ## ·name is the WezTerm workspace open on that directory.
  pinEnvironment()
  if watch > 0:
    return handOffToHark("mission-control", watch, ["--within", $within])

  let wezterm = startWezterm()
  let resolved = resolveAgents()
  for problem in resolved.problems:
    stderr.writeLine "mission-control: " & problem
  var rows = collect(resolved, within, getTime(), workspaces(wezterm))
  rows.sort do(a, b: Row) -> int:
    result = cmp(a.priority, b.priority)
    if result == 0:
      result = cmp(b.recency, a.recency)
    if result == 0:
      result = cmp(a.dir, b.dir)

  echo Bold & Cyan & " mission control" & Reset
  if rows.len == 0:
    echo paint(Dim, "   (nothing alive)")
  else:
    var table: seq[seq[string]]
    for row in rows:
      table.add row.cells
    for line in layout(table):
      echo line
  0

when isMainModule:
  cgParseErrorExitCode = 2
  clCfg.longPfxOk = false
  # dispatchCf, not dispatch: only it takes a rewritten command line.
  dispatchCf missionControl,
    cmdName = "mission-control",
    cmdLine = watchArgs(commandLineParams()),
    short = {"within": '\0', "watch": '\0'},
    help = {
      "within": "Codex sessions written within MIN minutes",
      "watch": "redraw every SECS seconds through `hark run` (bare: 2)",
    }
