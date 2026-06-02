## Parse a Claude Code transcript JSONL file into clean conversation turns.
##
## The transcript interleaves real human/assistant messages with non-conversation
## noise: tool results (user-role lines with a `toolUseResult` key / `tool_result`
## content blocks), slash-command echoes and their stdout (`<command-name>…`,
## `<local-command-stdout>…`), compaction summaries (`isCompactSummary`), subagent
## traffic (`isSidechain`), system-injected lines (`isMeta`), and non-conversation
## line types (`system`, `last-prompt`, …). Filtered out by default; genuine turns
## returned in chronological (append) order.
##
## Decoding uses json_serialization with typed Option[T] fields (repo convention):
## absent/null → None, never a silent zero-value; allowUnknownFields tolerates new
## fields. `message.content` is a union (JSON string OR array of content blocks),
## captured raw as Option[JsonString] and re-decoded by first char.

import std/[algorithm, options, os, strutils, times]
import json_serialization
import json_serialization/std/options as jsOptions

type
  Turn* = object
    role*: string ## "user" | "assistant"
    text*: string ## human text, or assistant text-blocks joined with "\n"
    timestamp*: string ## ISO 8601 from the line's `timestamp` ("" if absent)
    id*: string ## the line's `uuid` ("" if absent) — per-turn marker nonce

  ContentBlock = object
    `type`*: Option[string]
    text*: Option[string]
    name*: Option[string]
    content*: Option[JsonString] ## tool_result nested content (string or array)

  Message = object
    role*: Option[string]
    content*: Option[JsonString] ## raw: a JSON string or an array of blocks

  TranscriptLine = object
    `type`*: Option[string]
    message*: Option[Message]
    timestamp*: Option[string]
    isSidechain*: Option[bool]
    isMeta*: Option[bool]
    isCompactSummary*: Option[bool]
    toolUseResult*: Option[JsonString]
    uuid*: Option[string]

const NoiseUserPrefixes =
  ["<command-name>", "<command-message>", "<command-args>", "<local-command-stdout>"]

proc renderContent(
  raw: JsonString, includeToolNoise: bool
): tuple[text: string, isToolResult: bool]

proc blockText(b: ContentBlock, includeToolNoise: bool): string =
  case b.`type`.get("")
  of "text":
    b.text.get("")
  of "tool_use":
    if includeToolNoise:
      "[tool_use: " & b.name.get("?") & "]"
    else:
      ""
  of "tool_result":
    if includeToolNoise:
      let inner =
        if b.content.isSome:
          renderContent(b.content.get, includeToolNoise).text
        else:
          ""
      "[tool_result] " & inner
    else:
      ""
  else:
    ""

proc renderContent(
    raw: JsonString, includeToolNoise: bool
): tuple[text: string, isToolResult: bool] =
  ## Render a raw content fragment (JSON string or array of blocks) to display
  ## text, and report whether it is a tool_result array.
  let s = string(raw).strip()
  if s.len == 0:
    return ("", false)
  if s[0] == '"':
    return (
      (
        try:
          Json.decode(s, string)
        except CatchableError:
          ""
      ),
      false,
    )
  if s[0] != '[':
    return ("", false)
  let blocks =
    try:
      Json.decode(s, seq[ContentBlock], allowUnknownFields = true)
    except CatchableError:
      @[]
  var parts: seq[string] = @[]
  var isTr = false
  for b in blocks:
    if b.`type`.get("") == "tool_result":
      isTr = true
    let t = blockText(b, includeToolNoise)
    if t.len > 0:
      parts.add t
  (parts.join("\n"), isTr)

proc isNoiseUserText(text: string): bool =
  for p in NoiseUserPrefixes:
    if text.startsWith(p):
      return true
  false

proc projectSlug*(cwd: string): string =
  ## Claude Code's per-project transcript dir name: absolute cwd with every `/`
  ## and `.` replaced by `-`. Empirically derived, not documented.
  cwd.multiReplace(("/", "-"), (".", "-"))

proc parseTranscript*(path: string, includeToolNoise = false): seq[Turn] =
  ## Read a transcript JSONL into conversation turns (chronological). Best-effort:
  ## missing file or malformed line is skipped, never fatal. Empty-text turns
  ## (e.g. an assistant turn that only ran tools) are dropped unless
  ## includeToolNoise renders a marker.
  result = @[]
  if not fileExists(path):
    return
  for rawLine in lines(path):
    let line = rawLine.strip()
    if line.len == 0:
      continue
    var j: TranscriptLine
    try:
      j = Json.decode(line, TranscriptLine, allowUnknownFields = true)
    except CatchableError:
      continue
    let kind = j.`type`.get("")
    if kind notin ["user", "assistant"]:
      continue
    if j.isSidechain.get(false):
      continue
    if j.isMeta.get(false):
      continue
    if j.isCompactSummary.get(false):
      continue
    if j.toolUseResult.isSome and not includeToolNoise:
      continue
    let msg = j.message.get(Message())
    if msg.content.isNone:
      continue
    let (text, isToolResult) = renderContent(msg.content.get, includeToolNoise)
    if isToolResult and not includeToolNoise:
      continue
    let role = msg.role.get(kind)
    if role == "user" and isNoiseUserText(text):
      continue
    if text.len == 0:
      continue
    result.add Turn(
      role: role, text: text, timestamp: j.timestamp.get(""), id: j.uuid.get("")
    )

proc lastUserMessage*(turns: openArray[Turn]): Option[string] =
  ## Text of the most recent role=="user" turn, or none.
  for i in countdown(turns.high, 0):
    if turns[i].role == "user":
      return some(turns[i].text)
  none(string)

proc lastUserMessages*(turns: openArray[Turn], n: int): seq[string] =
  ## Up to the last n user-role texts, in chronological order.
  if n <= 0:
    return @[]
  result = @[]
  for t in turns:
    if t.role == "user":
      result.add t.text
  if result.len > n:
    result = result[^n .. ^1]

proc recentTurns*(turns: openArray[Turn], n: int): seq[Turn] =
  ## The last n turns (user+assistant interleaved). n <= 0 → empty.
  if n <= 0:
    return @[]
  let start = max(0, turns.len - n)
  turns[start .. ^1]

type TranscriptInfo* = object
  project*: string ## Claude Code project dir slug (see projectSlug)
  sessionId*: string ## transcript filename stem (the session UUID)
  path*: string ## absolute path to the .jsonl
  modified*: Time ## file mtime — the list's time signal
  size*: BiggestInt ## file size in bytes

proc listTranscripts*(
    projectFilter = "", since = none(Time), until = none(Time)
): seq[TranscriptInfo] =
  ## Every transcript under ~/.claude/projects/<slug>/*.jsonl, newest mtime first.
  ## projectFilter (non-empty) keeps only slugs containing it. since/until bound
  ## the mtime (inclusive). Missing projects root → empty seq (best-effort).
  result = @[]
  let root = getHomeDir() / ".claude" / "projects"
  if not dirExists(root):
    return
  for projDir in walkDirs(root / "*"):
    let slug = lastPathPart(projDir)
    if projectFilter.len > 0 and not slug.contains(projectFilter):
      continue
    for file in walkFiles(projDir / "*.jsonl"):
      let mt = getLastModificationTime(file)
      if since.isSome and mt < since.get:
        continue
      if until.isSome and mt > until.get:
        continue
      result.add TranscriptInfo(
        project: slug,
        sessionId: file.splitFile.name,
        path: file,
        modified: mt,
        size: getFileSize(file),
      )
  result.sort(
    proc(a, b: TranscriptInfo): int =
      cmp(b.modified, a.modified)
  )

proc currentTranscriptPath*(cwd = getCurrentDir()): Option[string] =
  ## Best-effort discovery: newest *.jsonl under ~/.claude/projects/<slug>/.
  ## `--path` is the authoritative override for callers that can't rely on it.
  let dir = getHomeDir() / ".claude" / "projects" / projectSlug(cwd)
  if not dirExists(dir):
    return none(string)
  var newest = ""
  var newestTime: Time
  var found = false
  for file in walkFiles(dir / "*.jsonl"):
    let mt = getLastModificationTime(file)
    if not found or mt > newestTime:
      newest = file
      newestTime = mt
      found = true
  if found:
    some(newest)
  else:
    none(string)
