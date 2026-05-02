## tv-claude-session: data backend for the `pick-claude-sessions` zsh
## function. Originally backed a Television channel, but TV's
## attach_to_tty gives bun-bundled claude a /dev/tty fd that kqueue
## rejects on Darwin (oven-sh/bun#24158). We moved the picker out of TV
## and into a small sk wrapper so claude inherits the user shell's
## original pty slave fds, which kqueue accepts.
##
## Subcommands (cligen dispatchMulti):
##   list                  - emit one record per session, newest-first
##   preview <line>        - render preview pane for a highlighted line
##   resume <line>         - emit `cd <cwd> && claude --resume <id>`
##                           for the user shell to eval
##   resume-zellij <line>  - emit `zellij action new-tab ...` for a new
##                           zellij tab; falls back to resume otherwise
##   delete <line>         - rm the session jsonl after a /dev/tty confirm
##   open <line>           - emit `$EDITOR <jsonl-path>` for shell eval
##
## Source line format (last whitespace-delimited token is the action key):
##   <marker>  <~/cwd>  <ai-title>  <MM-DD HH:MM>  <short8>
## marker is `●` if mtime is within ACTIVE_THRESHOLD_SEC, else a space.
## cwd + title come first because that's what the user actually recognizes
## when fuzzy-searching; the short-id is the action handle, not the label.

import std/[algorithm, json, os, strutils, syncio, terminal, times]

import cligen

type
  SessionMeta = object
    path: string
    fullId: string
    shortId: string
    mtime: int64
    title: string
    cwd: string
    branch: string
    startedTs: string

  PreviewMessage = object
    role: string
    timestamp: string
    text: string

const
  ActiveThresholdSec = 300
  ShortIdLen = 8
  PreviewMessageCount = 30
  PreviewMessageMaxChars = 360

# ---------------------------------------------------------------- helpers

proc projectsRoot(): string =
  getHomeDir() / ".claude" / "projects"

proc shortIdFor(uuid: string): string =
  if uuid.len >= ShortIdLen:
    uuid[0 ..< ShortIdLen]
  else:
    uuid

proc collapseHome(p: string): string =
  ## getHomeDir() returns the home path with a trailing slash; normalize it
  ## before comparing so /Users/me and /Users/me/sub both collapse cleanly.
  var home = getHomeDir()
  while home.len > 1 and home.endsWith("/"):
    home.setLen(home.len - 1)
  if p == home:
    "~"
  elif p.startsWith(home & "/"):
    "~" & p[home.len .. ^1]
  else:
    p

proc parseTimestamp(s: string): DateTime =
  ## Parses Claude's ISO-with-millis timestamps like 2026-05-01T03:58:25.616Z.
  ## Returns epoch on failure rather than raising — preview must never crash
  ## on a malformed entry.
  if s.len == 0:
    return fromUnix(0).inZone(utc())
  var input = s
  if input.endsWith("Z"):
    input.setLen(input.len - 1)
  try:
    parse(input, "yyyy-MM-dd'T'HH:mm:ss'.'fff", utc())
  except CatchableError:
    fromUnix(0).inZone(utc())

proc humanAge(seconds: int64): string =
  if seconds < 60:
    $seconds & "s"
  elif seconds < 3600:
    $(seconds div 60) & "m"
  elif seconds < 86400:
    $(seconds div 3600) & "h"
  else:
    $(seconds div 86400) & "d"

proc truncateText(s: string, limit: int): string =
  if s.len <= limit:
    s
  else:
    s[0 ..< limit] & "…"

# ---------------------------------------------------------------- json mining

proc extractText(content: JsonNode): string =
  ## message.content is either a JSON string or an array of typed blocks.
  if content.isNil:
    return ""
  case content.kind
  of JString:
    content.getStr
  of JArray:
    var parts: seq[string]
    for blk in content:
      if blk.kind != JObject:
        continue
      if blk{"type"}.getStr == "text":
        parts.add blk{"text"}.getStr
    parts.join("\n")
  else:
    ""

proc scanSession(path: string): SessionMeta =
  result.path = path
  let name = extractFilename(path)
  if name.endsWith(".jsonl"):
    result.fullId = name[0 ..< name.len - ".jsonl".len]
  else:
    result.fullId = name
  result.shortId = shortIdFor(result.fullId)
  result.mtime = getLastModificationTime(path).toUnix
  for line in lines(path):
    if line.len == 0:
      continue
    # Cheap pre-filter — only fully parse lines that might carry the fields
    # we care about. ai-title is regenerated periodically; last one wins.
    if line.contains("\"type\":\"ai-title\""):
      try:
        let j = parseJson(line)
        let t = j{"aiTitle"}.getStr
        if t.len > 0:
          result.title = t
      except CatchableError:
        discard
    elif line.contains("\"cwd\":") and (
      result.cwd.len == 0 or result.startedTs.len == 0
    ):
      try:
        let j = parseJson(line)
        if result.cwd.len == 0:
          let cwd = j{"cwd"}.getStr
          if cwd.len > 0:
            result.cwd = cwd
            let branch = j{"gitBranch"}.getStr
            if branch.len > 0:
              result.branch = branch
        if result.startedTs.len == 0:
          result.startedTs = j{"timestamp"}.getStr
      except CatchableError:
        discard

proc scanProjects(): seq[SessionMeta] =
  let root = projectsRoot()
  if not dirExists(root):
    return
  for projKind, projDir in walkDir(root):
    if projKind != pcDir:
      continue
    for kind, file in walkDir(projDir):
      if kind != pcFile:
        continue
      let n = extractFilename(file)
      if not n.endsWith(".jsonl"):
        continue
      result.add scanSession(file)
  result.sort(
    proc(a, b: SessionMeta): int =
      cmp(b.mtime, a.mtime)
  )

proc resolveShortId(short: string): SessionMeta =
  ## Walks ~/.claude/projects/*/<id>.jsonl looking for a unique prefix match.
  ## Returns a zeroed SessionMeta (path == "") on no/multi match.
  if short.len == 0:
    return
  var matches: seq[string]
  let root = projectsRoot()
  if not dirExists(root):
    return
  for projKind, projDir in walkDir(root):
    if projKind != pcDir:
      continue
    for kind, file in walkDir(projDir):
      if kind != pcFile:
        continue
      let n = extractFilename(file)
      if n.endsWith(".jsonl") and n.startsWith(short):
        matches.add file
  if matches.len == 1:
    return scanSession(matches[0])

proc collectPreviewMessages(path: string, count: int): seq[PreviewMessage] =
  ## Streams the file once, keeping a rolling window of the last `count`
  ## text-bearing user/assistant entries.
  for line in lines(path):
    if line.len == 0:
      continue
    if not (
      line.contains("\"type\":\"user\"") or line.contains("\"type\":\"assistant\"")
    ):
      continue
    try:
      let j = parseJson(line)
      let t = j{"type"}.getStr
      if t != "user" and t != "assistant":
        continue
      let msg = j{"message"}
      if msg.isNil:
        continue
      let text = extractText(msg{"content"})
      if text.len == 0:
        continue
      result.add PreviewMessage(role: t, timestamp: j{"timestamp"}.getStr, text: text)
      if result.len > count:
        result.delete(0)
    except CatchableError:
      discard

# ---------------------------------------------------------------- formatting

proc formatRecord(m: SessionMeta): string =
  let now = getTime().toUnix
  let active = (now - m.mtime) <= ActiveThresholdSec
  let marker = if active: "●" else: " "
  let stamp = format(fromUnix(m.mtime), "MM-dd hh:mm tt", local())
  let cwdDisplay =
    if m.cwd.len == 0:
      "?"
    else:
      collapseHome(m.cwd)
  let title = if m.title.len == 0: "(untitled)" else: m.title
  marker & "  " & cwdDisplay & "  " & title & "  " & stamp & "  " & m.shortId

proc parseShortIdFromLine(line: string): string =
  ## The action key is the LAST whitespace-delimited token on the line.
  ## Putting it last keeps the human-readable cwd + title up front for
  ## fuzzy search; the id is just for action lookup.
  let trimmed = line.strip()
  if trimmed.len == 0:
    return ""
  let parts = trimmed.splitWhitespace
  if parts.len == 0:
    return ""
  parts[^1]

proc lookupFromArgs(args: seq[string]): SessionMeta =
  if args.len == 0:
    quit("missing line argument", 2)
  let raw = args.join(" ")
  let short = parseShortIdFromLine(raw)
  if short.len == 0:
    quit("could not parse session short-id from: " & raw, 2)
  let m = resolveShortId(short)
  if m.path.len == 0:
    quit("no unique session matches short-id: " & short, 2)
  m

# ---------------------------------------------------------------- subcommands

proc list() =
  for m in scanProjects():
    echo formatRecord(m)

proc preview(line: seq[string]) =
  let m = lookupFromArgs(line)
  let useColor = isatty(stdout)

  proc dim(s: string): string =
    if useColor:
      "\e[2m" & s & "\e[0m"
    else:
      s

  proc bold(s: string): string =
    if useColor:
      "\e[1m" & s & "\e[0m"
    else:
      s

  proc role(s: string): string =
    if not useColor:
      return s
    if s == "user":
      "\e[36m" & s & "\e[0m" # cyan
    else:
      "\e[33m" & s & "\e[0m" # yellow

  let title = if m.title.len == 0: "(untitled)" else: m.title
  let cwdDisplay =
    if m.cwd.len == 0:
      "?"
    else:
      collapseHome(m.cwd)
  let branch = if m.branch.len == 0: "(no branch)" else: m.branch
  let startedDisplay =
    if m.startedTs.len == 0:
      "?"
    else:
      let dt = parseTimestamp(m.startedTs).inZone(local())
      dt.format("yyyy-MM-dd hh:mm tt")
  let now = getTime().toUnix
  let lastDt = inZone(fromUnix(m.mtime), local())
  let lastDisplay = lastDt.format("yyyy-MM-dd hh:mm tt")
  let age = now - m.mtime
  let lastSuffix =
    if age <= ActiveThresholdSec:
      " (● active)"
    else:
      " (" & humanAge(age) & " ago)"

  echo bold(title)
  echo dim("─".repeat(60))
  echo dim("session ") & m.fullId
  echo dim("cwd     ") & cwdDisplay
  echo dim("branch  ") & branch
  echo dim("started ") & startedDisplay
  echo dim("last    ") & lastDisplay & lastSuffix
  echo ""
  echo dim(
    "─── recent messages ─────────────────────────────────────"
  )

  let messages = collectPreviewMessages(m.path, PreviewMessageCount)
  if messages.len == 0:
    echo dim("(no text-bearing messages found)")
    return

  for msg in messages:
    let hhmm =
      if msg.timestamp.len == 0:
        "--:--"
      else:
        parseTimestamp(msg.timestamp).inZone(local()).format("hh:mm tt")
    var snippet = msg.text.replace("\n", " ").strip()
    snippet = truncateText(snippet, PreviewMessageMaxChars)
    echo ""
    echo "[" & role(msg.role) & " · " & dim(hhmm) & "] " & snippet

proc emitResumeShell(m: SessionMeta) =
  ## Emit `cd <cwd> && claude --resume <id>` for the user's shell to eval.
  ##
  ## No `exec` — claude runs as a child of the interactive shell so the
  ## user lands back at their prompt (in the session's cwd) after exit.
  ## No script(1) wrapper either: when this is eval'd in the parent shell
  ## claude inherits the shell's original pty slave fds, which bun's
  ## kqueue accepts (the workaround was only needed when TV gave claude
  ## dup'd /dev/tty fds — see oven-sh/bun#24158).
  if m.cwd.len == 0:
    quit("session has no recorded cwd: " & m.shortId, 1)
  if not dirExists(m.cwd):
    quit("session cwd no longer exists: " & m.cwd, 1)
  let qcwd = quoteShellPosix(m.cwd)
  let qid = quoteShellPosix(m.fullId)
  echo "cd " & qcwd & " && claude --resume " & qid

proc resume(line: seq[string]) =
  emitResumeShell(lookupFromArgs(line))

proc resumeZellij(line: seq[string]) =
  let m = lookupFromArgs(line)
  if getEnv("ZELLIJ").len == 0:
    # Outside zellij — fall back to inline resume (still emits a shell cmd).
    emitResumeShell(m)
    return
  if m.cwd.len == 0:
    quit("session has no recorded cwd: " & m.shortId, 1)
  if not dirExists(m.cwd):
    quit("session cwd no longer exists: " & m.cwd, 1)
  let title = if m.title.len == 0: "(untitled)" else: m.title
  let tabName = m.shortId & " · " & truncateText(title, 40)
  let qcwd = quoteShellPosix(m.cwd)
  let qname = quoteShellPosix(tabName)
  let qid = quoteShellPosix(m.fullId)
  # `zellij action new-tab` is fire-and-forget against the running zellij
  # server. The new tab gets its own pty slave from zellij, which bun
  # accepts — same reason the inline resume now works without script(1).
  echo "zellij action new-tab -c " & qcwd & " -n " & qname & " -- claude --resume " & qid

proc deleteCmd(line: seq[string]) =
  let m = lookupFromArgs(line)
  let title = if m.title.len == 0: "(untitled)" else: m.title
  stderr.writeLine "Delete session " & m.shortId & " (" & title & ")? [y/N] "
  let tty =
    try:
      open("/dev/tty", fmRead)
    except CatchableError:
      nil
  if tty.isNil:
    quit("could not open /dev/tty for confirmation", 1)
  let answer =
    try:
      tty.readLine().strip().toLowerAscii()
    except CatchableError:
      ""
  tty.close()
  if answer != "y" and answer != "yes":
    stderr.writeLine "aborted"
    quit(0)
  removeFile(m.path)
  # Sidechain dir, if present, holds subagent transcripts and tool results
  # for this session — drop it too so we don't leak orphans.
  let projDir = parentDir(m.path)
  let sideDir = projDir / m.fullId
  if dirExists(sideDir):
    removeDir(sideDir)
  stderr.writeLine "deleted " & m.shortId

proc openCmd(line: seq[string]) =
  let m = lookupFromArgs(line)
  let envEditor = getEnv("EDITOR")
  let editor = if envEditor.len > 0: envEditor else: "nvim"
  echo "exec " & quoteShellPosix(editor) & " " & quoteShellPosix(m.path)

# ---------------------------------------------------------------- entry

when isMainModule:
  dispatchMulti(
    [list, cmdName = "list"],
    [preview, cmdName = "preview", positional = "line"],
    [resume, cmdName = "resume", positional = "line"],
    [resumeZellij, cmdName = "resume-zellij", positional = "line"],
    [deleteCmd, cmdName = "delete", positional = "line"],
    [openCmd, cmdName = "open", positional = "line"],
  )
