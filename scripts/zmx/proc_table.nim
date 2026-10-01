## The processes living under zmx session daemons, and what they say about
## each session's occupancy.
##
## Two readers produce the same `ProcessInfo`:
##
## - `psNative` asks macOS libproc. `PROC_PIDT_SHORTBSDINFO` answers for every
##   process, root-owned ones included, so it supplies the parent links. Only
##   the descendants of the requested roots then get the costlier calls for
##   start time, memory and argv, each of which the kernel may refuse.
## - `psPs` parses `ps -axo`. It is the fallback when libproc fails and the
##   reader tests can stub.

import std/[algorithm, options, osproc, sets, strutils, tables, times]
import results
import zmx_types

export results

type
  ProcSource* = enum
    psNative
    psPs

  ProcError* = object
    msg*: string

const
  InfraShells = ["sh", "bash", "zsh", "fish", "dash"]
  PsCommand = "ps -axo pid=,ppid=,etime=,rss=,command="

# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

func baseName(p: ProcessInfo): string =
  ## The program's name: basename of argv[0], or of the command's first word
  ## when argv is unknown, without a login shell's leading `-`.
  let first =
    if p.argv.len > 0:
      p.argv[0]
    else:
      p.command.split(' ')[0]
  result = first.rsplit('/', maxsplit = 1)[^1]
  if result.startsWith('-'):
    result = result[1 .. ^1]

func isInfra*(p: ProcessInfo): bool =
  ## Shells and atuin's pty proxy hold a session open without being work.
  let base = baseName(p)
  base in InfraShells or (base == "atuin" and "pty-proxy" in p.command)

func occupancy*(procs: openArray[ProcessInfo]): (SessionOccupancy, Option[string]) =
  ## Active when any process is not infrastructure, named by the first such.
  for p in procs:
    if not isInfra(p):
      return (soActive, some(baseName(p)))
  (soIdle, none(string))

func formatEtime*(seconds: int64): string =
  ## Elapsed time in ps's format: `[[dd-]hh:]mm:ss`.
  let
    s = max(seconds, 0)
    days = s div 86400
    hours = s mod 86400 div 3600
    mins = s mod 3600 div 60
    secs = s mod 60
  result = align($mins, 2, '0') & ":" & align($secs, 2, '0')
  if days > 0 or hours > 0:
    result = align($hours, 2, '0') & ":" & result
  if days > 0:
    result = $days & "-" & result

func fmtAge*(seconds: int64): string =
  ## A session's age in its largest whole unit: `59m`, `23h`, `3d`.
  let s = max(seconds, 0)
  if s < 3600:
    $(s div 60) & "m"
  elif s < 86400:
    $(s div 3600) & "h"
  else:
    $(s div 86400) & "d"

func parseEtime*(etime: string): Option[int64] =
  ## Inverse of `formatEtime`.
  try:
    var rest = etime
    var total = 0'i64
    let dash = rest.find('-')
    if dash > 0:
      total = parseBiggestInt(rest[0 ..< dash]) * 86400
      rest = rest[dash + 1 .. ^1]
    let parts = rest.split(':')
    if parts.len notin 2 .. 3:
      return none(int64)
    var unit = 1'i64
    for i in countdown(parts.high, 0):
      total += parseBiggestInt(parts[i]) * unit
      unit *= 60
    some(total)
  except ValueError:
    none(int64)

func parsePsOutput*(text: string, now: int64): seq[ProcessInfo] =
  ## Lines of `pid ppid etime rss command...`. A malformed line is skipped.
  for line in text.splitLines:
    let f = line.splitWhitespace(maxsplit = 4)
    if f.len < 5:
      continue
    try:
      var p = ProcessInfo(
        pid: ProcessId(parseInt(f[0])),
        ppid: ProcessId(parseInt(f[1])),
        rssKb: some(parseInt(f[3])),
        command: f[4],
      )
      let elapsed = parseEtime(f[2])
      if elapsed.isSome:
        p.startedAt = some(now - elapsed.get)
      result.add p
    except ValueError:
      continue

func parseProcArgsEnv*(buf: openArray[char]): tuple[argv, env: seq[string]] =
  ## argv and environment out of a `KERN_PROCARGS2` buffer: an int32 argc, the
  ## exec path, NUL padding, argc NUL-terminated strings, then `KEY=value`
  ## strings up to the first empty one. The kernel leaves the environment out
  ## for Apple platform binaries.
  if buf.len < 4:
    return
  let argc =
    int(uint8(buf[0])) or (int(uint8(buf[1])) shl 8) or (int(uint8(buf[2])) shl 16) or
    (int(uint8(buf[3])) shl 24)
  var i = 4
  while i < buf.len and buf[i] != '\0':
    inc i
  while i < buf.len and buf[i] == '\0':
    inc i
  var cur = ""
  while i < buf.len:
    if buf[i] != '\0':
      cur.add buf[i]
    elif result.argv.len < argc:
      result.argv.add cur
      cur = ""
    elif cur.len == 0:
      break
    else:
      result.env.add cur
      cur = ""
    inc i

func parseProcArgs*(buf: openArray[char]): seq[string] =
  ## argv out of a `KERN_PROCARGS2` buffer.
  parseProcArgsEnv(buf).argv

func parseEnvValue*(psLine, key: string): Option[string] =
  ## `key`'s value in a `ps eww` line, where the environment trails the
  ## command as space-separated `KEY=value` words.
  let marker = " " & key & "="
  let at = psLine.find(marker)
  if at < 0:
    return none(string)
  let start = at + marker.len
  let stop = psLine.find(' ', start)
  some(psLine[start ..< (if stop < 0: psLine.len else: stop)])

func startsVariable(word: string): bool =
  ## `NAME=...`, where NAME is a shell identifier.
  let eq = word.find('=')
  eq > 0 and word[0] in IdentStartChars and word[0 ..< eq].allCharsInSet(IdentChars)

func parsePsEnv*(psLine: string): seq[string] =
  ## The `KEY=value` words of a `ps eww` line, from the fifth word on; a word
  ## that does not start a variable continues the one before it.
  let words = psLine.splitWhitespace()
  for i in 4 ..< words.len:
    if startsVariable(words[i]):
      result.add words[i]
    elif result.len > 0:
      result[^1].add " " & words[i]

func childrenByParent(links: openArray[(int, int)]): Table[int, seq[int]] =
  ## (pid, ppid) pairs to parent -> children, children in ascending pid order.
  for (pid, ppid) in links:
    result.mgetOrPut(ppid, @[]).add pid
  for kids in result.mvalues:
    kids.sort()

func walk(children: Table[int, seq[int]], root: int): seq[int] =
  ## Breadth-first descendants of `root`, excluding it.
  var seen = toHashSet([root])
  var queue = children.getOrDefault(root)
  var head = 0
  while head < queue.len:
    let pid = queue[head]
    inc head
    if seen.containsOrIncl(pid):
      continue
    result.add pid
    queue.add children.getOrDefault(pid)

func descendants*(all: openArray[ProcessInfo], root: ProcessId): seq[ProcessInfo] =
  ## The processes under `root`, breadth-first, siblings in ascending pid order.
  var links: seq[(int, int)]
  var byPid: Table[int, ProcessInfo]
  for p in all:
    links.add (int(p.pid), int(p.ppid))
    byPid[int(p.pid)] = p
  for pid in walk(childrenByParent(links), int(root)):
    result.add byPid[pid]

# ---------------------------------------------------------------------------
# Readers
# ---------------------------------------------------------------------------

proc readPs(roots: openArray[ProcessId]): Result[seq[ProcessInfo], ProcError] =
  try:
    let (output, code) = execCmdEx(PsCommand, options = {poUsePath})
    if code != 0:
      return err(ProcError(msg: "`ps` exited " & $code))
    let all = parsePsOutput(output, getTime().toUnix)
    var procs: seq[ProcessInfo]
    for root in roots:
      procs.add descendants(all, root)
    ok(procs)
  except OSError, IOError:
    err(ProcError(msg: "could not run `ps`: " & getCurrentExceptionMsg()))

when defined(macosx):
  proc proc_listallpids(
    buffer: pointer, buffersize: cint
  ): cint {.importc, header: "<libproc.h>".}

  proc proc_pidinfo(
    pid, flavor: cint, arg: uint64, buffer: pointer, buffersize: cint
  ): cint {.importc, header: "<libproc.h>".}

  proc sysctl(
    name: ptr cint,
    namelen: cuint,
    oldp: pointer,
    oldlenp: ptr csize_t,
    newp: pointer,
    newlen: csize_t,
  ): cint {.importc, header: "<sys/sysctl.h>".}

  const
    ProcPidTBsdInfo = 3.cint
    ProcPidTaskInfo = 4.cint
    ProcPidTShortBsdInfo = 13.cint
    CtlKern = 1.cint
    KernArgMax = 8.cint
    KernProcArgs2 = 49.cint

  type
    # Partial views: Nim takes each struct's layout and size from the header.
    ProcShortInfo {.importc: "struct proc_bsdshortinfo", header: "<sys/proc_info.h>".} = object
      pbsi_ppid: uint32
      pbsi_comm: array[16, char]

    ProcBsdInfo {.importc: "struct proc_bsdinfo", header: "<sys/proc_info.h>".} = object
      pbi_start_tvsec: uint64

    ProcTaskInfo {.importc: "struct proc_taskinfo", header: "<sys/proc_info.h>".} = object
      pti_resident_size: uint64

  proc shortName(info: ProcShortInfo): string =
    for c in info.pbsi_comm:
      if c == '\0':
        break
      result.add c

  proc argMax(): int =
    var mib = [CtlKern, KernArgMax]
    var value: cint
    var size = csize_t(sizeof(value))
    if sysctl(addr mib[0], 2, addr value, addr size, nil, 0) == 0 and value > 0:
      int(value)
    else:
      1 shl 20

  proc readArgsBuf(pid: int, buf: var seq[char]): int =
    ## Fills `buf` with the process's `KERN_PROCARGS2` block and returns its
    ## length, 0 when the kernel refuses.
    var mib = [CtlKern, KernProcArgs2, cint(pid)]
    var size = csize_t(buf.len)
    if sysctl(addr mib[0], 3, addr buf[0], addr size, nil, 0) == 0:
      int(size)
    else:
      0

  proc readArgv(pid: int, buf: var seq[char]): seq[string] =
    let size = readArgsBuf(pid, buf)
    parseProcArgs(buf.toOpenArray(0, size - 1))

  var envBuf: seq[char] # ARG_MAX is a megabyte: allocated once, on first use

  proc readEnvAllNative(pid: ProcessId): seq[string] =
    if envBuf.len == 0:
      envBuf = newSeq[char](argMax())
    let size = readArgsBuf(int(pid), envBuf)
    parseProcArgsEnv(envBuf.toOpenArray(0, size - 1)).env

  proc readNative(roots: openArray[ProcessId]): Result[seq[ProcessInfo], ProcError] =
    let estimate = proc_listallpids(nil, 0)
    if estimate <= 0:
      return err(ProcError(msg: "proc_listallpids failed"))
    var pids = newSeq[cint](estimate + 64)
    let count = proc_listallpids(addr pids[0], cint(pids.len * sizeof(cint)))
    if count <= 0:
      return err(ProcError(msg: "proc_listallpids failed"))

    var links: seq[(int, int)]
    var names: Table[int, string]
    for i in 0 ..< min(int(count), pids.len):
      var info: ProcShortInfo
      if proc_pidinfo(pids[i], ProcPidTShortBsdInfo, 0, addr info, cint(sizeof(info))) >
          0:
        links.add (int(pids[i]), int(info.pbsi_ppid))
        names[int(pids[i])] = shortName(info)

    let children = childrenByParent(links)
    var parentOf: Table[int, int]
    for (pid, ppid) in links:
      parentOf[pid] = ppid

    var argBuf = newSeq[char](argMax())
    var procs: seq[ProcessInfo]
    for root in roots:
      for pid in walk(children, int(root)):
        var p = ProcessInfo(pid: ProcessId(pid), ppid: ProcessId(parentOf[pid]))
        var bsd: ProcBsdInfo
        if proc_pidinfo(cint(pid), ProcPidTBsdInfo, 0, addr bsd, cint(sizeof(bsd))) > 0:
          p.startedAt = some(int64(bsd.pbi_start_tvsec))
        var task: ProcTaskInfo
        if proc_pidinfo(cint(pid), ProcPidTaskInfo, 0, addr task, cint(sizeof(task))) > 0:
          p.rssKb = some(int(task.pti_resident_size div 1024))
        p.argv = readArgv(pid, argBuf)
        # Some programs pad argv with empty strings when they retitle
        # themselves; ps shows those as trailing blanks.
        p.command = p.argv.join(" ").strip()
        if p.command.len == 0:
          p.command = names[pid]
        procs.add p
    ok(procs)

else:
  proc readNative(roots: openArray[ProcessId]): Result[seq[ProcessInfo], ProcError] =
    err(ProcError(msg: "no native process reader on this platform"))

  proc readEnvAllNative(pid: ProcessId): seq[string] =
    @[]

proc readEnvAllPs(pid: ProcessId): seq[string] =
  try:
    let (output, code) = execCmdEx("ps eww -p " & $pid, options = {poUsePath})
    if code == 0:
      for line in output.splitLines:
        result.add parsePsEnv(line)
  except OSError, IOError:
    discard

proc readEnv*(source: ProcSource, pid: ProcessId): seq[string] =
  ## A process's exec-time environment as `KEY=value` strings. Empty when it
  ## is hidden (Apple platform binaries) or the process is gone.
  case source
  of psNative:
    readEnvAllNative(pid)
  of psPs:
    readEnvAllPs(pid)

proc readEnvNative(pid: ProcessId, key: string): Option[string] =
  for entry in readEnvAllNative(pid):
    if entry.startsWith(key & "="):
      return some(entry[key.len + 1 .. ^1])
  none(string)

proc readEnvPs(pid: ProcessId, key: string): Option[string] =
  try:
    let (output, code) = execCmdEx("ps eww -p " & $pid, options = {poUsePath})
    if code == 0:
      for line in output.splitLines:
        let value = parseEnvValue(line, key)
        if value.isSome:
          return value
  except OSError, IOError:
    discard
  none(string)

proc readEnvVar*(source: ProcSource, pid: ProcessId, key: string): Option[string] =
  ## `key` in a process's exec-time environment. `none` when it is unset, the
  ## process is gone, or its environment is hidden (Apple platform binaries,
  ## other users' processes).
  case source
  of psNative:
    readEnvNative(pid, key)
  of psPs:
    readEnvPs(pid, key)

proc readProcesses*(
    source: ProcSource, roots: openArray[ProcessId]
): Result[seq[ProcessInfo], ProcError] =
  ## Every descendant of every root, grouped by root in breadth-first order.
  case source
  of psNative:
    readNative(roots)
  of psPs:
    readPs(roots)
