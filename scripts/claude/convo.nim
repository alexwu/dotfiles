## convo — read clean conversation turns out of a Claude Code transcript.
##
## Subcommands: `last-user [-n N]` (last N typed user messages, default 1),
## `recent -n N` (last N interleaved turns, default 5), `all`. Default output is
## clean text (`role: text`); `--json` emits a structured array. `--path`
## overrides transcript auto-detection (hooks pass the payload transcript_path);
## `--include-tool-results` keeps tool-result noise (and tool-only turns).

import std/[json, options, strutils, times]
import ../lib/transcript
import cligen

proc resolvePath(path: string): string =
  if path.len > 0:
    return path
  let auto = currentTranscriptPath()
  if auto.isSome:
    return auto.get
  stderr.writeLine(
    "convo: no transcript found for the current directory; pass --path FILE"
  )
  quit(1)

proc turnsToJson(turns: seq[Turn]): JsonNode =
  result = newJArray()
  for t in turns:
    result.add %*{"role": t.role, "text": t.text, "timestamp": t.timestamp}

proc emit(turns: seq[Turn], json: bool) =
  if json:
    echo turnsToJson(turns)
  else:
    var parts: seq[string] = @[]
    for t in turns:
      parts.add t.role & ": " & t.text
    echo parts.join("\n\n")

# NOTE: the `include_tool_results` param is spelled snake_case deliberately so
# cligen renders the long option as `--include-tool-results`. Nim treats it as
# identical to includeToolResults.
proc lastUser(n = 1, path = "", json = false, include_tool_results = false) =
  ## Print the last N genuine typed user messages (default 1).
  let msgs =
    lastUserMessages(parseTranscript(resolvePath(path), include_tool_results), n)
  if json:
    var arr = newJArray()
    for m in msgs:
      arr.add %m
    echo arr
  else:
    echo msgs.join("\n\n")

proc recent(n = 5, path = "", json = false, include_tool_results = false) =
  ## Print the last N conversation turns (interleaved).
  let turns = parseTranscript(resolvePath(path), include_tool_results)
  emit(recentTurns(turns, n), json)

proc parseTs(ts: string): Option[Time] =
  ## Transcript timestamps are ISO 8601 UTC ("2026-08-04T03:48:52.186Z").
  if ts.len == 0:
    return none(Time)
  for fmt in ["yyyy-MM-dd'T'HH:mm:ss'.'fff'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'"]:
    try:
      return some(parse(ts, fmt, utc()).toTime)
    except TimeParseError:
      discard
  none(Time)

proc localDay(t: Time): string =
  t.local.format("yyyy-MM-dd")

func gapMarker(a, b: Time): string =
  ## "" under 3 hours; otherwise a human-scale seam.
  let hours = (b - a).inHours
  if hours < 3:
    ""
  elif hours < 24:
    "[— resumed after " & $hours & " hours —]"
  elif hours < 48:
    "[— resumed the next day —]"
  else:
    "[— resumed after " & $((b - a).inDays) & " days —]"

proc allTurns(path = "", day = "", json = false, include_tool_results = false) =
  ## Print the whole filtered conversation. `--day YYYY-MM-DD` emits only that
  ## LOCAL day's turns; when the session began on an earlier day a header says
  ## so, and multi-hour gaps inside the window get seam markers (text mode
  ## only — `--json` gets the filtered turns, no markers). Turns without a
  ## timestamp are dropped in day mode (they can't be dated).
  let turns = parseTranscript(resolvePath(path), include_tool_results)
  if day.len == 0:
    emit(turns, json)
    return
  try:
    discard parse(day, "yyyy-MM-dd")
  except TimeParseError:
    stderr.writeLine("convo all: bad --day (use YYYY-MM-DD): " & day)
    quit(1)

  var kept: seq[Turn] = @[]
  var keptTimes: seq[Time] = @[]
  var firstTime = none(Time)
  for t in turns:
    let ts = parseTs(t.timestamp)
    if ts.isNone:
      continue
    if firstTime.isNone:
      firstTime = ts
    if localDay(ts.get) == day:
      kept.add t
      keptTimes.add ts.get
  if kept.len == 0:
    return
  if json:
    echo turnsToJson(kept)
    return

  var parts: seq[string] = @[]
  let firstDay = localDay(firstTime.get)
  if firstDay < day:
    let earlier =
      (parse(day, "yyyy-MM-dd").toTime - parse(firstDay, "yyyy-MM-dd").toTime).inDays
    let unit = if earlier == 1: " day earlier; " else: " days earlier; "
    parts.add "[session began " & $earlier & unit & "earlier portion omitted]"
  for i, t in kept:
    if i > 0:
      let marker = gapMarker(keptTimes[i - 1], keptTimes[i])
      if marker.len > 0:
        parts.add marker
    parts.add t.role & ": " & t.text
  echo parts.join("\n\n")

func humanSize(n: BiggestInt): string =
  const Units = ["B", "K", "M", "G", "T"]
  if n < 1024:
    return $n & "B"
  var size = n.float
  var i = 0
  while size >= 1024 and i < Units.high:
    size /= 1024
    inc i
  formatFloat(size, ffDecimal, 1) & Units[i]

proc parseBound(s, which: string): Option[Time] =
  ## --since/--until value (full ISO or YYYY-MM-DD) → Time; none when empty.
  ## A bare date is local midnight. Exits 1 on a malformed value.
  if s.len == 0:
    return none(Time)
  for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]:
    try:
      return some(parse(s, fmt).toTime)
    except TimeParseError:
      discard
  stderr.writeLine("convo list: bad --" & which & " (use YYYY-MM-DD): " & s)
  quit(1)

proc rowsToJson(rows: seq[TranscriptInfo]): JsonNode =
  result = newJArray()
  for r in rows:
    result.add %*{
      "project": r.project,
      "sessionId": r.sessionId,
      "path": r.path,
      "modified": r.modified.local.format("yyyy-MM-dd'T'HH:mm:sszzz"),
      "size": r.size,
    }

proc list(project = "", since = "", until = "", json = false) =
  ## List Claude Code transcripts across all projects (newest first).
  let rows =
    listTranscripts(project, parseBound(since, "since"), parseBound(until, "until"))
  if json:
    echo rowsToJson(rows)
    return
  for r in rows:
    echo r.modified.local.format("yyyy-MM-dd HH:mm") & "  " & align(
      humanSize(r.size), 8
    ) & "  " & r.sessionId & "  " & r.project

when isMainModule:
  dispatchMulti(
    [lastUser, cmdName = "last-user"],
    [recent, cmdName = "recent"],
    [allTurns, cmdName = "all"],
    [list, cmdName = "list"],
  )
