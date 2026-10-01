## Reads zmx's session list into `ZmxSession` values.
##
## `zmx list` has no JSON mode: each line is tab-separated `key=value` fields.
## The first four are always `name`, `pid`, `clients`, `created`; then come
## zmx's optional `cwd`, `cmd`, `ended`, `exit_code` in that order; every field
## after those is a label. Fields are read by position because a label may
## reuse a structural key.

import std/[os, osproc, strutils, uri]
import results
import zmx_types

export results

type
  ZmxErrorKind* = enum
    zeSpawn
    zeExit

  ZmxError* = object
    kind*: ZmxErrorKind
    msg*: string

proc confstr(
  name: cint, buf: cstring, len: csize_t
): csize_t {.importc, header: "<unistd.h>".}

const CsDarwinUserTempDir = 65537.cint

proc pinEnvironment*() =
  ## Resolve `zmx` and `ps` the way the Bash tools do, and point TMPDIR at the
  ## launchd GUI temp dir, where zmx keeps its sockets. Agents namespace
  ## TMPDIR, and GUI launchers pass a minimal PATH.
  putEnv(
    "PATH",
    getHomeDir() / ".local/bin" & ":/opt/homebrew/bin:/usr/bin:/bin:" & getEnv("PATH"),
  )
  when defined(macosx):
    var buf = newString(1024)
    let n = confstr(CsDarwinUserTempDir, buf.cstring, buf.len.csize_t)
    if n > 1 and n.int <= buf.len:
      buf.setLen(n.int - 1)
      putEnv("TMPDIR", buf)

func fieldValue(field: string): string =
  field[field.find('=') + 1 .. ^1]

func decodeCwd*(raw: string): string =
  ## `file://host/path%20a/` becomes `/path a`. A plain path, from a daemon
  ## older than zmx 0.8, passes through. The trailing `/` a shell reports goes.
  result = raw
  let scheme = result.find("://")
  if scheme > 0:
    let slash = result.find('/', scheme + 3)
    result =
      if slash < 0:
        ""
      else:
        decodeUrl(result[slash .. ^1], decodePlus = false)
  if result.len > 1 and result.endsWith('/'):
    result.setLen(result.len - 1)

func parseListLine*(line: string): Opt[ZmxSession] =
  ## One `zmx list` line. `none` for an unreachable session, which reports
  ## `err=` and `status=` in place of a pid.
  let f = line.split('\t')
  if f.len < 4 or not f[1].startsWith("pid="):
    return Opt.none(ZmxSession)
  var s = ZmxSession(current: line.startsWith("→"))
  s.name = ZmxSessionName(fieldValue(f[0]))
  try:
    s.pid = ProcessId(parseInt(fieldValue(f[1])))
    s.clients = parseInt(fieldValue(f[2]))
    s.created = parseBiggestInt(fieldValue(f[3]))
  except ValueError:
    return Opt.none(ZmxSession)
  var i = 4
  if i < f.len and f[i].startsWith("cwd="):
    s.cwd = decodeCwd(fieldValue(f[i]))
    inc i
  for key in ["cmd=", "ended=", "exit_code="]:
    if i < f.len and f[i].startsWith(key):
      inc i
  for label in f[i .. ^1]:
    let eq = label.find('=')
    if eq > 0:
      s.labels[label[0 ..< eq]] = label[eq + 1 .. ^1]
  Opt.some(s)

func parseList*(output: string): seq[ZmxSession] =
  for line in output.splitLines:
    let session = parseListLine(line)
    if session.isSome:
      result.add session.get

proc listSessions*(): Result[seq[ZmxSession], ZmxError] =
  ## Every reachable session. No sessions is `ok(@[])`.
  pinEnvironment()
  try:
    let (output, code) = execCmdEx("zmx list", options = {poUsePath})
    if code != 0:
      return err(ZmxError(kind: zeExit, msg: "`zmx list` exited " & $code))
    ok(parseList(output))
  except OSError, IOError:
    err(
      ZmxError(
        kind: zeSpawn, msg: "could not run `zmx list`: " & getCurrentExceptionMsg()
      )
    )
