## zmx-env — the environment of every process running inside a zmx session.
##
## The environment is the kernel's exec-time snapshot (`KERN_PROCARGS2`):
##
## - it is what the process was started with, not what it has changed since;
## - Apple platform binaries (/bin/zsh, /bin/sh, ...) hide theirs; third-party
##   processes (claude, node, codex, ...) show theirs.
##
## Built to ~/.local/bin/zmx-env by run_onchange_build-scripts.sh.tmpl.

import std/[algorithm, sequtils]
import cligen
import regex
import zmx_snapshot, term_out

const Hidden =
  "(no env visible " & EmDash &
  " exec-time snapshot unavailable; Apple platform binaries hide theirs)"

proc matchesAny(entry: string, patterns: openArray[Regex2]): bool =
  for pattern in patterns:
    if entry.contains(pattern):
      return true

proc zmxEnv(args: seq[string]): int =
  ## The exec-time environment of each process inside a zmx session, sorted.
  ##
  ## Patterns are case-insensitive regular expressions; an entry is shown when
  ## any of them matches:
  ##   zmx-env demon-shuu ZMX_ CLAUDE_ WEZTERM_
  if args.len == 0:
    stderr.writeLine "usage: zmx-env <session> [pattern]..."
    return 2
  let name = args[0]
  var patterns: seq[Regex2]
  for pattern in args[1 .. ^1]:
    try:
      patterns.add re2("(?i)" & pattern)
    except RegexError:
      stderr.writeLine "zmx-env: bad pattern '" & pattern & "': " &
        getCurrentExceptionMsg()
      return 2

  let views = snapshot().valueOr:
    stderr.writeLine "zmx-env: " & error
    return 1
  let found = views.filterIt($it.session.name == name)
  if found.len == 0:
    stderr.writeLine "zmx-env: no session named '" & name & "'"
    return 1
  let view = found[0]
  if view.procs.len == 0:
    echo "session '" & name & "' (daemon " & $view.session.pid &
      ") has no running processes"
    return 0

  let source = procSource()
  for p in view.procs:
    echo Bold & "== " & name & " " & $p.pid & " (" &
      (if p.argv.len > 0: p.argv[0] else: p.command) & ")" & Reset
    var entries = readEnv(source, p.pid)
    if patterns.len > 0:
      entries = entries.filterIt(matchesAny(it, patterns))
    entries.sort()
    if entries.len == 0:
      echo paint(Dim, Hidden)
    else:
      for entry in entries:
        echo entry
    echo ""
  0

when isMainModule:
  cgParseErrorExitCode = 2
  clCfg.longPfxOk = false
  dispatch zmxEnv, cmdName = "zmx-env", help = {"args": "<session> [pattern]..."}
