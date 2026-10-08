## Reads the session list into `ZmxSession` values.
##
## The list comes from `bmx list --json`: bmx (lulu-tools) is a client for bmx
## hosts and zmx daemons alike, so one read covers both. Each row carries
## `name`, `pid`, `clients`, `created_at`, `cwd` and a `labels` object; a
## daemon's `cmd` and `task` are fields of their own and never labels.

import std/[os, osproc, strutils, uri]
import results
import zmx_types

export results

type
  ZmxErrorKind* = enum
    zeSpawn
    zeExit
    zeOutput

  ZmxError* = object
    kind*: ZmxErrorKind
    msg*: string

proc confstr(
  name: cint, buf: cstring, len: csize_t
): csize_t {.importc, header: "<unistd.h>".}

const CsDarwinUserTempDir = 65537.cint

proc pinEnvironment*() =
  ## Resolve `bmx` and `ps` the way the launchers do, and point TMPDIR at the
  ## launchd GUI temp dir, where the session sockets are. Agents namespace
  ## TMPDIR, and GUI launchers pass a minimal PATH. `~/.local/bin` stays first:
  ## the test harness puts its stubs there.
  let home = getHomeDir()
  putEnv(
    "PATH",
    home / ".local/bin" & ":" & home / ".cargo/bin" & ":/opt/homebrew/bin:/usr/bin:/bin:" &
      getEnv("PATH"),
  )
  when defined(macosx):
    var buf = newString(1024)
    let n = confstr(CsDarwinUserTempDir, buf.cstring, buf.len.csize_t)
    if n > 1 and n.int <= buf.len:
      buf.setLen(n.int - 1)
      putEnv("TMPDIR", buf)

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

func number(s: string, first, last: int): Opt[int] =
  ## The digits `s[first .. last]` as a number.
  var n = 0
  for i in first .. last:
    if s[i] notin Digits:
      return Opt.none(int)
    n = n * 10 + (ord(s[i]) - ord('0'))
  Opt.some(n)

func epochOf*(stamp: string): Opt[int64] =
  ## `2026-10-08T16:36:31Z` as epoch seconds. bmx prints UTC; a fraction of a
  ## second, when there is one, is dropped. `none` for anything else.
  if stamp.len < 20 or stamp[4] != '-' or stamp[7] != '-' or stamp[10] != 'T' or
      stamp[13] != ':' or stamp[16] != ':' or not stamp.endsWith('Z'):
    return Opt.none(int64)
  let
    year = ?number(stamp, 0, 3)
    month = ?number(stamp, 5, 6)
    day = ?number(stamp, 8, 9)
    hour = ?number(stamp, 11, 12)
    minute = ?number(stamp, 14, 15)
    second = ?number(stamp, 17, 18)
  if month notin 1 .. 12 or day notin 1 .. 31 or hour > 23 or minute > 59 or second > 60:
    return Opt.none(int64)
  # Days from the civil date, counting years from March so a leap day is last.
  let
    y =
      if month <= 2:
        year - 1
      else:
        year
    era = y div 400
    yearOfEra = y - era * 400
    dayOfYear = (153 * (if month > 2: month - 3 else: month + 9) + 2) div 5 + day - 1
    dayOfEra = yearOfEra * 365 + yearOfEra div 4 - yearOfEra div 100 + dayOfYear
    days = era * 146_097 + dayOfEra - 719_468
  Opt.some(days.int64 * 86_400 + hour * 3600 + minute * 60 + second)

func toSession(row: BmxRowIn, current: string): Opt[ZmxSession] =
  ## `none` for a row with no pid, which is a session the client could not
  ## probe, and for one whose name or creation time cannot be read.
  let name = row.name.get("")
  if name.len == 0 or row.pid.isNone:
    return Opt.none(ZmxSession)
  Opt.some(
    ZmxSession(
      name: ZmxSessionName(name),
      pid: ProcessId(row.pid.get),
      clients: row.clients.get(0),
      created: ?epochOf(row.createdAt.get("")),
      cwd: decodeCwd(row.cwd.get("")),
      current: current.len > 0 and name == current,
      labels: row.labels.get(initOrderedTable[string, string]()),
    )
  )

proc parseList*(output, current: string): Result[seq[ZmxSession], string] =
  ## The sessions in `bmx list --json`'s output, in its order. `current` is the
  ## session this process runs in, empty outside one.
  var rows: seq[BmxRowIn]
  try:
    rows = ClaudeJson.decode(output, seq[BmxRowIn])
  except SerializationError as e:
    return err(e.msg)
  var sessions: seq[ZmxSession]
  for row in rows:
    let session = toSession(row, current)
    if session.isSome:
      sessions.add session.get
  ok(sessions)

proc listSessions*(): Result[seq[ZmxSession], ZmxError] =
  ## Every reachable session. No sessions is `ok(@[])`.
  pinEnvironment()
  try:
    let (output, code) = execCmdEx("bmx list --json", options = {poUsePath})
    if code != 0:
      return err(ZmxError(kind: zeExit, msg: "`bmx list --json` exited " & $code))
    parseList(output, getEnv("ZMX_SESSION")).mapErr(
      proc(msg: string): ZmxError =
        ZmxError(kind: zeOutput, msg: "could not read `bmx list --json`: " & msg)
    )
  except OSError, IOError:
    err(
      ZmxError(
        kind: zeSpawn,
        msg: "could not run `bmx list --json`: " & getCurrentExceptionMsg(),
      )
    )
