## Every zmx session joined with its descendant processes and occupancy: the
## one read `zmx-ps` and `zmx-which` both start from.

import std/[os, sequtils]
import zmx_types, zmx_sessions, proc_table

export zmx_types, zmx_sessions, proc_table

type SessionView* = object
  session*: ZmxSession
  procs*: seq[ProcessInfo] ## descendants of the session daemon, breadth-first
  state*: SessionOccupancy
  running*: Option[string]

func reapVerdict*(view: SessionView): ReapVerdict =
  ## Only a detached session with an idle tree is reaped.
  if view.session.clients > 0:
    rvAttached
  elif view.state == soActive:
    rvActive
  else:
    rvReap

proc procSource*(): ProcSource =
  ## libproc, unless `ZMX_PS_SOURCE=ps` asks for the `ps` reader.
  if getEnv("ZMX_PS_SOURCE") == "ps": psPs else: psNative

proc snapshot*(): Result[seq[SessionView], string] =
  ## Falls back to the `ps` reader when libproc fails.
  let sessions = listSessions().valueOr:
    return err(error.msg)
  let roots = sessions.mapIt(it.pid)
  let source = procSource()
  var procs = readProcesses(source, roots)
  if procs.isErr and source == psNative:
    procs = readProcesses(psPs, roots)
  let all = procs.valueOr:
    return err(error.msg)
  var views: seq[SessionView]
  for s in sessions:
    let tree = descendants(all, s.pid)
    let (state, running) = occupancy(tree)
    views.add SessionView(session: s, procs: tree, state: state, running: running)
  ok(views)
