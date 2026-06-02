## convo — read clean conversation turns out of a Claude Code transcript.
##
## Subcommands: `last-user [-n N]` (last N typed user messages, default 1),
## `recent -n N` (last N interleaved turns, default 5), `all`. Default output is
## clean text (`role: text`); `--json` emits a structured array. `--path`
## overrides transcript auto-detection (hooks pass the payload transcript_path);
## `--include-tool-results` keeps tool-result noise (and tool-only turns).

import std/[json, options, strutils]
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

when isMainModule:
  dispatchMulti(
    [lastUser, cmdName = "last-user"],
    [recent, cmdName = "recent"],
    [allTurns, cmdName = "all"],
  )
