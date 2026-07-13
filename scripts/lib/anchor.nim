## Shared machinery for the `persona-anchor` / `reward-anchor` hooks.
##
## Two concerns live here:
##
## 1. Hook plumbing — per-session counter state, kill switch, frequency,
##    stdin payload parsing, and the `additionalContext` envelope. Identical
##    between the two binaries apart from a state directory and two env-var
##    names, both of which are parameters here.
##
## 2. Anchor resolution — `resolveAnchor` picks WHICH prompt body to inject,
##    based on the current working directory and the host coding agent:
##
##      1. `$<KIND>_ANCHOR_FILE`  — explicit override, highest priority
##      2. the TOML manifest      — `$ANCHORS_MANIFEST`, else
##                                  `~/.claude/anchors/anchors.toml`
##      3. the legacy default     — `~/.claude/anchors/<kind>_anchor.md`
##      4. nothing                — caller injects nothing, exits 0
##
##    Manifest rules are an ordered array-of-tables per kind. The first rule
##    whose `when` clause matches AND whose `file` exists on disk wins. A
##    matched rule pointing at a missing file falls THROUGH to the next rule,
##    so a typo in `file =` can't silently disable an anchor. `skip = true`
##    short-circuits deliberately — it has no file to miss.

import std/[json, options, os, strutils]
import parsetoml

# ---------------------------------------------------------------------------
# Anchor resolution
# ---------------------------------------------------------------------------

type Resolved* = object
  path*: string ## "" when nothing resolved
  skip*: bool ## a rule matched with `skip = true` — inject nothing

proc isUnder*(child, parent: string): bool =
  ## Path-component-boundary prefix test. `~` is expanded on both sides.
  ## `/a/bc` is NOT under `/a/b`.
  let
    c = expandTilde(child).absolutePath.normalizedPath
    p = expandTilde(parent).absolutePath.normalizedPath
  c == p or c.startsWith(p & DirSep)

proc anyIsUnder(node: TomlValueRef, cwd: string): bool =
  ## `cwd_under` may be a bare string or an array of strings; any-match.
  case node.kind
  of TomlValueKind.String:
    isUnder(cwd, node.getStr)
  of TomlValueKind.Array:
    for e in node.getElems:
      if e.kind == TomlValueKind.String and isUnder(cwd, e.getStr):
        return true
    false
  else:
    false

proc anyEquals(node: TomlValueRef, want: string): bool =
  ## `agent` may be a bare string or an array of strings; any-match.
  case node.kind
  of TomlValueKind.String:
    node.getStr == want
  of TomlValueKind.Array:
    for e in node.getElems:
      if e.kind == TomlValueKind.String and e.getStr == want:
        return true
    false
  else:
    false

proc ruleMatches*(rule: TomlValueRef, cwd, agent: string): bool =
  ## Every key in `when` must match (AND). No `when` = unconditional.
  let w = rule.getOrDefault("when") # nil when absent — never raises
  if w.isNil:
    return true
  if w.kind != TomlValueKind.Table:
    return false
  let cu = w.getOrDefault("cwd_under")
  if not cu.isNil and not anyIsUnder(cu, cwd):
    return false
  let ag = w.getOrDefault("agent")
  if not ag.isNil and not anyEquals(ag, agent):
    return false
  true

proc manifestPath*(): string =
  let raw = getEnv("ANCHORS_MANIFEST", "")
  if raw.len > 0:
    expandTilde(raw)
  else:
    getHomeDir() / ".claude" / "anchors" / "anchors.toml"

proc resolveFromManifest*(kind, cwd, agent: string): Option[Resolved] =
  ## `none` = no manifest / unparseable / no rule matched with an existing file.
  let mf = manifestPath()
  if not fileExists(mf):
    return none(Resolved)
  var doc: TomlValueRef
  try:
    doc = parsetoml.parseFile(mf) # raises on malformed TOML
  except CatchableError:
    return none(Resolved)
  # Resolve through symlinks: the manifest is typically `~/.claude/anchors/
  # anchors.toml` pointing into the prompts repo, and `file =` is relative to
  # where the prompts actually live, not to the link. `absolutePath` also
  # raises ValueError unless its `root` is already absolute.
  var baseDir: string
  try:
    baseDir = expandFilename(mf).parentDir
  except OSError:
    baseDir = mf.absolutePath.parentDir
  for rule in doc.getOrDefault(kind).getElems: # nil-safe: missing key -> @[]
    if rule.kind != TomlValueKind.Table or not ruleMatches(rule, cwd, agent):
      continue
    if rule.getOrDefault("skip").getBool(false):
      return some(Resolved(skip: true))
    let f = rule.getOrDefault("file").getStr("")
    if f.len == 0:
      continue # malformed rule
    let full = expandTilde(f).absolutePath(baseDir)
    if not fileExists(full):
      continue # a typo must not disable the anchor — try the next rule
    return some(Resolved(path: full))
  none(Resolved)

proc resolveAnchor*(kind, envVar, legacyRelPath, cwd, agent: string): Resolved =
  ## 1. $<KIND>_ANCHOR_FILE  2. manifest  3. legacy default  4. nothing
  let override = getEnv(envVar, "")
  if override.len > 0:
    return Resolved(path: expandTilde(override))
  let m = resolveFromManifest(kind, cwd, agent)
  if m.isSome:
    return m.get
  let legacy = getHomeDir() / legacyRelPath
  if fileExists(legacy):
    return Resolved(path: legacy)
  Resolved()

# ---------------------------------------------------------------------------
# Per-session counter state — `~/.claude/<stateDir>/<session_id>.json`
#   Shape: `{"count": <int>, "last_fired_at": "<iso8601>"}`
# `last_fired_at` is set only on actual fires. Survives `--resume`/`--continue`
# because session_id is stable. `saveState` creates the parent dir lazily.
# ---------------------------------------------------------------------------

type State* = object
  count*: int
  lastFiredAt*: string

proc stateFilePath(stateDir, sessionId: string): string =
  getHomeDir() / ".claude" / stateDir / (sessionId & ".json")

proc loadState*(stateDir, sessionId: string): State =
  let path = stateFilePath(stateDir, sessionId)
  if not fileExists(path):
    return State()
  try:
    let j = parseJson(readFile(path))
    if j.kind == JObject:
      result.count = j{"count"}.getInt(0)
      result.lastFiredAt = j{"last_fired_at"}.getStr("")
  except JsonParsingError, ValueError, IOError, OSError:
    discard

proc saveState*(stateDir, sessionId: string, state: State) =
  let path = stateFilePath(stateDir, sessionId)
  try:
    createDir(path.parentDir)
    var payload = %*{"count": state.count}
    if state.lastFiredAt.len > 0:
      payload["last_fired_at"] = %state.lastFiredAt
    writeFile(path, $payload)
  except IOError, OSError:
    discard

# ---------------------------------------------------------------------------
# Hook plumbing
# ---------------------------------------------------------------------------

proc currentFrequency*(envVar: string, default: int): int =
  let raw = getEnv(envVar, "")
  if raw.len == 0:
    return default
  try:
    let n = parseInt(raw)
    if n > 0: n else: default
  except ValueError:
    default

proc disabled*(envVar: string): bool =
  getEnv(envVar, "1") == "0"

proc loadReminder*(path: string): string =
  if not fileExists(path):
    return ""
  try:
    return readFile(path)
  except IOError, OSError:
    return ""

proc applyTemplate*(body: string, pairs: openArray[(string, string)]): string =
  result = body
  for (k, v) in pairs:
    result = result.replace(k, v)

proc inject*(eventName, body: string) =
  echo %*{"hookSpecificOutput": {"hookEventName": eventName, "additionalContext": body}}

proc readStdinPayload*(): JsonNode =
  try:
    parseJson(stdin.readAll())
  except JsonParsingError, ValueError, IOError:
    nil
