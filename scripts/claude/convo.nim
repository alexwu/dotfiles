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

proc allTurns(path = "", json = false, include_tool_results = false) =
  ## Print the whole filtered conversation.
  let turns = parseTranscript(resolvePath(path), include_tool_results)
  emit(turns, json)

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
