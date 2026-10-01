## zmx-agent-label — record a coding agent's identity on its ambient zmx session.
##
## Runs from the agent's lifecycle hooks with the hook JSON on stdin and labels
## $ZMX_SESSION, so zmx-ps and zmx-which read the association instead of
## inferring it from the process environment:
##
##   agent=<agent>  <agent>_session=<session id>  <agent>_pid=<agent pid>
##
## Labels carry identity only. Turn state (busy, waiting, idle) stays with the
## agent's own status API.
##
## Usage: zmx-agent-label set <agent>     SessionStart: startup, resume, clear, compact
##        zmx-agent-label unset <agent>   SessionEnd
##
## set    overwrites the labels, unless another live agent process already owns
##        them: a nested agent (`claude -p` from a tool call) inherits
##        ZMX_SESSION and must not take over its parent's session.
## unset  removes this agent's three keys, and only while <agent>_session still
##        names the ending session. /clear ends one id and starts the next; the
##        guard keeps a late SessionEnd from erasing the new id. Other labels
##        and the session itself are never touched.
##
## Exits 0 on everything but a usage error, so a hook cannot block the agent.
## Diagnostics go to stderr, and nothing goes to stdout: a SessionStart hook's
## stdout lands in the agent's context.
##
## Built to ~/.local/bin/zmx-agent-label by run_onchange_build-scripts.sh.tmpl.

import std/[os, osproc, streams, strutils, terminal]
from std/posix import kill, Pid
import zmx_types, zmx_sessions

const
  Usage = "usage: zmx-agent-label set|unset <agent>   (hook JSON on stdin)"
  AgentChars = {'a' .. 'z', '0' .. '9'}
  LabelChars = Letters + Digits + {'.', '_', '-'} # all a zmx label value may hold

proc zmx(args: openArray[string]): tuple[output: string, code: int] =
  ## Runs `zmx` and captures everything it prints. A failure to start is code 1.
  try:
    let process =
      startProcess("zmx", args = args, options = {poUsePath, poStdErrToStdOut})
    defer:
      process.close()
    process.inputStream.close()
    result.output = process.outputStream.readAll()
    result.code = process.waitForExit()
  except OSError, IOError:
    result = ("", 1)

proc label(key: string): string =
  ## The current session's value for `key`; empty when unset or unreadable.
  let (output, code) = zmx(["get", ".", key])
  if code == 0:
    result = output.strip()

proc isLive(owner: string): bool =
  try:
    kill(Pid(parseInt(owner)), 0) == 0
  except ValueError:
    false

proc main(): int =
  let args = commandLineParams()
  if args.len < 2 or args[0] notin ["set", "unset"] or args[1].len == 0 or
      args[1][0] notin {'a' .. 'z'} or not args[1].allCharsInSet(AgentChars):
    stderr.writeLine Usage
    return 2
  let (action, agent) = (args[0], args[1])

  let session = getEnv("ZMX_SESSION")
  if session.len == 0:
    return 0

  var id = ""
  if not isatty(stdin):
    try:
      id = ClaudeJson.decode(stdin.readAll(), HookIn).sessionId.get("")
    except SerializationError, IOError:
      discard
  if id.len == 0 or not id.allCharsInSet(LabelChars):
    stderr.writeLine "zmx-agent-label: no usable session_id on stdin, leaving labels alone"
    return 0

  pinEnvironment()
  if action == "set":
    var pid = getEnv("CLAUDE_PID")
    if pid.len == 0 or not pid.allCharsInSet(Digits):
      pid = ""
    let owner = label(agent & "_pid")
    if owner.len > 0 and pid.len > 0 and owner != pid and isLive(owner):
      stderr.writeLine "zmx-agent-label: " & session & " is labelled for live pid " &
        owner & ", not relabelling"
      return 0
    if zmx(
      ["set", ".", "agent=" & agent, agent & "_session=" & id, agent & "_pid=" & pid]
    ).code != 0:
      stderr.writeLine "zmx-agent-label: could not label " & session
  elif label(agent & "_session") == id:
    if zmx(["set", ".", "agent=", agent & "_session=", agent & "_pid="]).code != 0:
      stderr.writeLine "zmx-agent-label: could not clear labels on " & session
  0

when isMainModule:
  quit main()
