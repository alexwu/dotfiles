## Claude Code security hook — Nim port of the upstream `security-guidance`
## plugin (plugins/security-guidance/hooks/security_reminder_hook.py).
##
## Subcommands (cligen dispatchMulti):
##   check     — PreToolUse(Edit|Write|MultiEdit): scan content for known
##               risky patterns; emit a `permissionDecision` envelope when
##               a rule matches AND the warning hasn't fired earlier this
##               session (per-session, per-file, per-rule dedup).
##   cleanup   — SessionEnd: remove THIS session's state file.
##
## Output protocol:
##   - Default: `permissionDecision: "ask"` — surface the reminder as a
##     confirmation prompt rather than a hard block (upstream Python used
##     sys.exit(2) to block, which is too aggressive for a "reminder").
##   - `SEC_GUARD_MODE=deny` flips to `permissionDecision: "deny"` to
##     match upstream Python behavior exactly.
##   - Silent (exit 0, no output) when no rule matches, or when the same
##     (file, rule) pair has already been flagged this session.
##
## Kill switch: `ENABLE_SECURITY_REMINDER=0` → immediate exit 0.
##
## State file: `~/.claude/security_warnings_state_<session_id>.json`,
## same path + format as upstream so a hot-swap mid-session doesn't lose
## already-shown warnings. JSON array of `"<file_path>-<rule_name>"`.
##
## Extension: add a new rule by appending a `Rule` literal to the `rules`
## sequence below. For path-based rules, write a `proc (p: string): bool
## {.nimcall.}` matcher. For content-based rules, populate `needles`.

import std/[json, os, strutils, sets]
import cligen

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

type
  RuleKind = enum
    rkContent
    rkPath

  PathMatcher = proc(p: string): bool {.nimcall.}

  Rule = object
    name: string
    reminder: string
    kind: RuleKind
    needles: seq[string]
    pathFn: PathMatcher

  Mode = enum
    mAsk
    mDeny

# ---------------------------------------------------------------------------
# Path-based matcher
# ---------------------------------------------------------------------------

proc isGhActionsWorkflow(p: string): bool {.nimcall.} =
  (".github/workflows/" in p) and (p.endsWith(".yml") or p.endsWith(".yaml"))

# ---------------------------------------------------------------------------
# Rule registry — verbatim from upstream Python
# ---------------------------------------------------------------------------

let rules: seq[Rule] = @[
  Rule(
    name: "github_actions_workflow",
    kind: rkPath,
    pathFn: isGhActionsWorkflow,
    reminder:
      """You are editing a GitHub Actions workflow file. Be aware of these security risks:

1. **Command Injection**: Never use untrusted input (like issue titles, PR descriptions, commit messages) directly in run: commands without proper escaping
2. **Use environment variables**: Instead of ${{ github.event.issue.title }}, use env: with proper quoting
3. **Review the guide**: https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/

Example of UNSAFE pattern to avoid:
run: echo "${{ github.event.issue.title }}"

Example of SAFE pattern:
env:
  TITLE: ${{ github.event.issue.title }}
run: echo "$TITLE"

Other risky inputs to be careful with:
- github.event.issue.body
- github.event.pull_request.title
- github.event.pull_request.body
- github.event.comment.body
- github.event.review.body
- github.event.review_comment.body
- github.event.pages.*.page_name
- github.event.commits.*.message
- github.event.head_commit.message
- github.event.head_commit.author.email
- github.event.head_commit.author.name
- github.event.commits.*.author.email
- github.event.commits.*.author.name
- github.event.pull_request.head.ref
- github.event.pull_request.head.label
- github.event.pull_request.head.repo.default_branch
- github.head_ref""",
  ),
  Rule(
    name: "child_process_exec",
    kind: rkContent,
    needles: @["child_process.exec", "exec(", "execSync("],
    reminder:
      """⚠️ Security Warning: Using child_process.exec() can lead to command injection vulnerabilities.

This codebase provides a safer alternative: src/utils/execFileNoThrow.ts

Instead of:
  exec(`command ${userInput}`)

Use:
  import { execFileNoThrow } from '../utils/execFileNoThrow.js'
  await execFileNoThrow('command', [userInput])

The execFileNoThrow utility:
- Uses execFile instead of exec (prevents shell injection)
- Handles Windows compatibility automatically
- Provides proper error handling
- Returns structured output with stdout, stderr, and status

Only use exec() if you absolutely need shell features and the input is guaranteed to be safe.""",
  ),
  Rule(
    name: "new_function_injection",
    kind: rkContent,
    needles: @["new Function"],
    reminder:
      "⚠️ Security Warning: Using new Function() with dynamic strings can lead to code injection vulnerabilities. Consider alternative approaches that don't evaluate arbitrary code. Only use new Function() if you truly need to evaluate arbitrary dynamic code.",
  ),
  Rule(
    name: "eval_injection",
    kind: rkContent,
    needles: @["eval("],
    reminder:
      "⚠️ Security Warning: eval() executes arbitrary code and is a major security risk. Consider using JSON.parse() for data parsing or alternative design patterns that don't require code evaluation. Only use eval() if you truly need to evaluate arbitrary code.",
  ),
  Rule(
    name: "react_dangerously_set_html",
    kind: rkContent,
    needles: @["dangerouslySetInnerHTML"],
    reminder:
      "⚠️ Security Warning: dangerouslySetInnerHTML can lead to XSS vulnerabilities if used with untrusted content. Ensure all content is properly sanitized using an HTML sanitizer library like DOMPurify, or use safe alternatives.",
  ),
  Rule(
    name: "document_write_xss",
    kind: rkContent,
    needles: @["document.write"],
    reminder:
      "⚠️ Security Warning: document.write() can be exploited for XSS attacks and has performance issues. Use DOM manipulation methods like createElement() and appendChild() instead.",
  ),
  Rule(
    name: "innerHTML_xss",
    kind: rkContent,
    needles: @[".innerHTML =", ".innerHTML="],
    reminder:
      "⚠️ Security Warning: Setting innerHTML with untrusted content can lead to XSS vulnerabilities. Use textContent for plain text or safe DOM methods for HTML content. If you need HTML support, consider using an HTML sanitizer library such as DOMPurify.",
  ),
  Rule(
    name: "pickle_deserialization",
    kind: rkContent,
    needles: @["pickle"],
    reminder:
      "⚠️ Security Warning: Using pickle with untrusted content can lead to arbitrary code execution. Consider using JSON or other safe serialization formats instead. Only use pickle if it is explicitly needed or requested by the user.",
  ),
  Rule(
    name: "os_system_injection",
    kind: rkContent,
    needles: @["os.system", "from os import system"],
    reminder:
      "⚠️ Security Warning: This code appears to use os.system. This should only be used with static arguments and never with arguments that could be user-controlled.",
  ),
]

# ---------------------------------------------------------------------------
# State file (dedup) — same path + format as upstream
# ---------------------------------------------------------------------------

proc stateFilePath(sessionId: string): string =
  getHomeDir() / ".claude" / ("security_warnings_state_" & sessionId & ".json")

proc loadState(sessionId: string): HashSet[string] =
  result = initHashSet[string]()
  let path = stateFilePath(sessionId)
  if not fileExists(path):
    return
  try:
    let j = parseJson(readFile(path))
    if j.kind == JArray:
      for item in j:
        if item.kind == JString:
          result.incl(item.getStr(""))
  except JsonParsingError, ValueError, IOError, OSError:
    discard

proc saveState(sessionId: string, shown: HashSet[string]) =
  let path = stateFilePath(sessionId)
  try:
    createDir(path.parentDir)
    var arr = newJArray()
    for key in shown:
      arr.add(%key)
    writeFile(path, $arr)
  except IOError, OSError:
    discard

# ---------------------------------------------------------------------------
# Input extraction (per-tool, matches upstream Python)
# ---------------------------------------------------------------------------

proc extractContent(toolName: string, toolInput: JsonNode): string =
  if toolInput == nil or toolInput.kind != JObject:
    return ""
  case toolName
  of "Write":
    toolInput{"content"}.getStr("")
  of "Edit":
    toolInput{"new_string"}.getStr("")
  of "MultiEdit":
    let edits = toolInput{"edits"}
    if edits == nil or edits.kind != JArray:
      return ""
    var parts: seq[string] = @[]
    for edit in edits:
      if edit.kind == JObject:
        parts.add edit{"new_string"}.getStr("")
    parts.join(" ")
  else:
    ""

# ---------------------------------------------------------------------------
# Rule matching
# ---------------------------------------------------------------------------

proc matchRule(r: Rule, filePath, content: string): bool =
  case r.kind
  of rkPath:
    if r.pathFn == nil:
      return false
    r.pathFn(filePath)
  of rkContent:
    if content.len == 0:
      return false
    for needle in r.needles:
      if needle in content:
        return true
    false

proc findMatch(filePath, content: string): tuple[name, reminder: string, found: bool] =
  # Match Python's `file_path.lstrip("/")` — strip leading slashes only.
  let normPath = filePath.strip(chars = {'/'}, trailing = false)
  for r in rules:
    if matchRule(r, normPath, content):
      return (r.name, r.reminder, true)
  ("", "", false)

# ---------------------------------------------------------------------------
# Output envelope
# ---------------------------------------------------------------------------

proc currentMode(): Mode =
  if getEnv("SEC_GUARD_MODE").toLowerAscii == "deny": mDeny else: mAsk

proc warn(mode: Mode, reason: string) =
  let decision =
    case mode
    of mAsk: "ask"
    of mDeny: "deny"
  echo %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": decision,
      "permissionDecisionReason": reason,
    }
  }

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

proc handleCheck(data: JsonNode) =
  if getEnv("ENABLE_SECURITY_REMINDER", "1") == "0":
    return

  let toolName = data{"tool_name"}.getStr("")
  if toolName notin ["Edit", "Write", "MultiEdit"]:
    return

  let toolInput = data{"tool_input"}
  let filePath = toolInput{"file_path"}.getStr("")
  if filePath.len == 0:
    return

  let content = extractContent(toolName, toolInput)
  let (ruleName, reminder, found) = findMatch(filePath, content)
  if not found:
    return

  let sessionId = data{"session_id"}.getStr("default")
  var shown = loadState(sessionId)
  let key = filePath & "-" & ruleName
  if key in shown:
    return

  shown.incl(key)
  saveState(sessionId, shown)
  warn(currentMode(), reminder)

proc handleCleanup(data: JsonNode) =
  let sessionId = data{"session_id"}.getStr("")
  if sessionId.len == 0:
    return
  let path = stateFilePath(sessionId)
  if fileExists(path):
    try:
      removeFile(path)
    except OSError:
      discard

# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------

proc readStdinPayload(): JsonNode =
  try:
    parseJson(stdin.readAll())
  except JsonParsingError, ValueError, IOError:
    nil

proc check() =
  ## PreToolUse — scans Edit/Write/MultiEdit inputs against the rule list.
  let data = readStdinPayload()
  if data != nil:
    handleCheck(data)

proc cleanup() =
  ## SessionEnd — removes THIS session's dedup state file.
  let data = readStdinPayload()
  if data != nil:
    handleCleanup(data)

when isMainModule:
  dispatchMulti([check, cmdName = "check"], [cleanup, cmdName = "cleanup"])
