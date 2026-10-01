## Codex sessions that wrote to their rollout file recently.
##
## Codex has no live-status command, so a rollout's mtime is its liveness. The
## files are `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`, and line one is the
## `session_meta` record carrying the session id, directory and branch.

import std/[algorithm, os, strutils, times]
import results
import zmx_types

export results, times, zmx_types

type CodexSession* = object
  id*: Option[CodexSessionId]
  cwd*, branch*: Option[string]
  modified*: int64 ## the rollout file's mtime, epoch seconds

proc decodeCodexMeta*(line: string, modified: int64): Opt[CodexSession] =
  ## A rollout's first line. A line that is not a JSON object is none.
  try:
    let meta = ClaudeJson.decode(line, CodexMetaIn)
    var session = CodexSession(modified: modified)
    if meta.payload.isSome:
      let payload = meta.payload.get
      session.cwd = payload.cwd
      if payload.id.isSome:
        session.id = some(CodexSessionId(payload.id.get))
      if payload.git.isSome:
        session.branch = payload.git.get.branch
    ok(session)
  except SerializationError:
    Opt.none(CodexSession)

proc recentCodexSessions*(root: string, withinMin: int, now: Time): seq[CodexSession] =
  ## Rollouts under `root` written less than `withinMin` minutes before `now`,
  ## newest first. The comparison is at `Time` precision, so `withinMin = 0`
  ## matches nothing. A file that cannot be read or decoded is skipped, and a
  ## missing `root` is no sessions.
  let cutoff = now - initDuration(minutes = withinMin)
  var found: seq[tuple[session: CodexSession, path: string]]
  for path in walkDirRec(root):
    if not path.endsWith(".jsonl"):
      continue
    try:
      let modified = getLastModificationTime(path)
      if modified <= cutoff:
        continue
      let file = open(path)
      defer:
        file.close()
      var line: string
      if not file.readLine(line):
        continue
      let session = decodeCodexMeta(line, modified.toUnix)
      if session.isSome:
        found.add (session.get, path)
    except IOError, OSError:
      continue
  found.sort do(a, b: tuple[session: CodexSession, path: string]) -> int:
    result = cmp(b.session.modified, a.session.modified)
    if result == 0:
      result = cmp(a.path, b.path)
  for entry in found:
    result.add entry.session
