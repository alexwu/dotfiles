## zmx-reap — kill detached zmx sessions whose process tree is idle.
##
## A detached session may still host live work: an agent, an editor with
## unsaved buffers, a build. A session is reaped only when no client is
## attached and its daemon's descendants are nothing but shells. Anything else
## is skipped; kill those by hand with `zmx kill <name>`.
##
## `active` is the session's occupancy, not an agent's turn status.
##
## Built to ~/.local/bin/zmx-reap by run_onchange_build-scripts.sh.tmpl.

import std/[osproc, sequtils, times]
import cligen
import zmx_snapshot, term_out

const Columns = ["NAME", "AGE", "VERDICT", "DIR"]

proc killSessions(names: seq[string]): int =
  ## `zmx kill <names...>` on this terminal; its exit code, 1 when it cannot run.
  try:
    let zmx = startProcess(
      "zmx", args = @["kill"] & names, options = {poUsePath, poParentStreams}
    )
    defer:
      zmx.close()
    zmx.waitForExit()
  except OSError:
    1

proc zmxReap(kill = false, all = false): int =
  ## Kill detached zmx sessions whose process tree is idle. Dry run unless
  ## --kill. Active sessions are always skipped.
  let views = snapshot().valueOr:
    stderr.writeLine "zmx-reap: " & error
    return 1

  let now = getTime().toUnix
  var rows = @[Columns.mapIt(paint(Bold, it))]
  var reap: seq[string]
  var active, attached = 0
  for view in views:
    var verdict: string
    case reapVerdict(view)
    of rvReap:
      reap.add $view.session.name
      verdict = paint(Red, $rvReap)
    of rvActive:
      inc active
      verdict = paint(Yellow, $rvActive & ":" & view.running.get(""))
    of rvAttached:
      inc attached
      if not all:
        continue
      verdict = paint(Dim, $rvAttached)
    rows.add @[
      $view.session.name,
      fmtAge(now - view.session.created),
      verdict,
      paint(Dim, view.session.cwd),
    ]
  for line in layout(rows):
    echo line
  echo ""

  let skipped = $active & " active + " & $attached & " attached skipped"
  if reap.len == 0:
    echo paint(Green, "nothing to reap") & " (" & $active & " detached-active, " &
      $attached & " attached " & EmDash & " all skipped)"
  elif not kill:
    echo $reap.len & " reapable, " & skipped & " " & EmDash & " dry run. Re-run with " &
      paint(Bold, "--kill") & " to execute."
  else:
    stdout.flushFile() # `zmx kill` writes to this terminal next
    let code = killSessions(reap)
    if code != 0:
      stderr.writeLine "zmx-reap: `zmx kill` exited " & $code
      return 1
    echo paint(Green, "killed " & $reap.len & " session(s)") & ", " & skipped
  0

when isMainModule:
  cgParseErrorExitCode = 2
  clCfg.longPfxOk = false
  dispatch zmxReap,
    cmdName = "zmx-reap",
    short = {"kill": 'k', "all": 'a'},
    help = {
      "kill": "kill the reapable sessions",
      "all": "also list attached sessions, which are never reaped",
    }
