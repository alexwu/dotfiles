## zmx-ps — every zmx session as JSON: session info, labels, descendant
## processes, and an active/idle verdict. `bmx list --json`, which it reads,
## has the sessions; this adds what runs in each.
##
## Schema per session:
##   { name, pid, clients, created, cwd, current, labels: { key: value }, age_s,
##     procs: [ { pid, etime, rss_kb, command } ],
##     state: "active"|"idle", running: <program>|null }
##
## "active" is SESSION OCCUPANCY: some descendant is not shell or
## atuin-pty-proxy infrastructure. It is not a Claude agent's "busy" turn
## status (see agent-sessions). "labels" is every zmx label on the session,
## verbatim; agents register their identity there (see zmx-agent-label).
##
## Processes are read through libproc. ZMX_PS_SOURCE=ps forces the `ps`
## reader, which is also the fallback when libproc fails.
##
## Built to ~/.local/bin/zmx-ps by run_onchange_build-scripts.sh.tmpl.

import std/[sequtils, strutils, times]
import cligen
import regex
import zmx_snapshot

type Filter = object
  active: bool
  rx: Regex2

proc compileFilter(flag, pattern: string): Result[Filter, string] =
  if pattern.len == 0:
    return ok(Filter())
  try:
    ok(Filter(active: true, rx: re2("(?i)" & pattern)))
  except RegexError:
    err("--" & flag & ": bad pattern '" & pattern & "': " & getCurrentExceptionMsg())

func matches(f: Filter, s: string): bool =
  not f.active or s.contains(f.rx)

func labelMatches(labels: OrderedTable[string, string], want: string): bool =
  ## `K` asks that the label is set; `K=V` that it equals V.
  if want.len == 0:
    return true
  let eq = want.find('=')
  if eq < 0:
    want in labels
  else:
    labels.getOrDefault(want[0 ..< eq], "\0") == want[eq + 1 .. ^1]

func toOut(p: ProcessInfo, now: int64): ProcOut =
  ProcOut(
    pid: int(p.pid),
    etime:
      if p.startedAt.isSome:
        some(formatEtime(now - p.startedAt.get))
      else:
        none(string),
    rssKb: p.rssKb,
    command: p.command,
  )

proc zmxPs(
    name = "",
    dir = "",
    hosting = "",
    label = "",
    detached = false,
    attached = false,
    active = false,
    idle = false,
    names = false,
): int =
  ## Every zmx session as JSON: info, labels, descendant processes, and an
  ## active/idle occupancy verdict.
  ##
  ## Examples:
  ##   zmx-ps --detached --idle --names | xargs bmx kill
  ##   zmx-ps --hosting claude | jaq '.[] | {name, procs: (.procs | length)}'
  ##   zmx-ps --label agent=claude --names
  if detached and attached:
    stderr.writeLine "zmx-ps: --detached and --attached exclude each other"
    return 2
  if active and idle:
    stderr.writeLine "zmx-ps: --active and --idle exclude each other"
    return 2
  var filters: array[3, Filter]
  for i, (flag, pattern) in [("name", name), ("dir", dir), ("hosting", hosting)]:
    filters[i] = compileFilter(flag, pattern).valueOr:
      stderr.writeLine "zmx-ps: " & error
      return 2

  let views = snapshot().valueOr:
    stderr.writeLine "zmx-ps: " & error
    return 1

  let now = getTime().toUnix
  var rows: seq[SessionOut]
  for view in views:
    let (s, tree, state, running) = (view.session, view.procs, view.state, view.running)
    if not filters[0].matches($s.name) or not filters[1].matches(s.cwd):
      continue
    if (detached and s.clients != 0) or (attached and s.clients == 0):
      continue
    if (active and state != soActive) or (idle and state != soIdle):
      continue
    if not labelMatches(s.labels, label):
      continue
    if filters[2].active and not tree.anyIt(filters[2].matches(it.command)):
      continue
    rows.add SessionOut(
      name: $s.name,
      pid: int(s.pid),
      clients: s.clients,
      created: s.created,
      cwd: s.cwd,
      current: s.current,
      labels: s.labels,
      ageS: now - s.created,
      procs: tree.mapIt(toOut(it, now)),
      state: state,
      running: running,
    )

  if names:
    for row in rows:
      echo row.name
  else:
    echo ZmxJson.encode(rows, pretty = true)
  0

when isMainModule:
  cgParseErrorExitCode = 2
  # Exact long names only: with prefix matching on, `--name RE` is read as the
  # boolean `--names` and its value becomes a stray argument.
  clCfg.longPfxOk = false
  dispatch zmxPs,
    cmdName = "zmx-ps",
    short = {
      "name": '\0',
      "dir": '\0',
      "hosting": '\0',
      "label": '\0',
      "detached": '\0',
      "attached": '\0',
      "active": '\0',
      "idle": '\0',
      "names": '\0',
    },
    help = {
      "name": "session name matches RE (case-insensitive)",
      "dir": "session cwd matches RE",
      "hosting": "any descendant command matches RE (e.g. claude)",
      "label": "label K is set, or K=V: it equals V",
      "detached": "no client attached",
      "attached": "at least one client attached",
      "active": "a descendant is doing work",
      "idle": "only shells and atuin-pty-proxy",
      "names": "print matching session names only (for xargs)",
    }
