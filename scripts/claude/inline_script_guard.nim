## Claude Code PreToolUse hook for the `Bash` tool.
##
## Inline Python / Ruby scripts — `python -c '…'`, `ruby -e '…'`, or an
## interpreter fed by a heredoc — are a second language embedded inside a
## shell command. The sibling Bash guards parse *shell*: they see
## `python3 -c "<script>"` as a single command word and stop at the quote.
## The script itself is invisible to them.
##
## This hook closes that blind spot. When a command carries an inline Python
## or Ruby script it pipes the WHOLE command to `llm` (codex provider), which
## returns a structured summary — what the script writes, deletes, sends over
## the network, executes, or reads — then forces `permissionDecision: "ask"`
## with that summary attached. The model only ever explains; it never decides.
## The human always confirms.
##
## LLM-decide gate: with ALLOW_LLM_DECIDE set, the explain-then-ask flow is
## replaced by the shared `llm_decide.adjudicate` (with recent UNTRUSTED
## conversation as context) returning allow / ask / deny — so a trivially-safe
## inline script the user authorized can skip the prompt. The new
## `inline-script-classify` prompt folds a what-it-does summary into the
## decision reason, so the explanation survives on the ask/deny paths.
## Classifier unavailable (adjudicate → none) → a plain `ask` (never a silent
## allow on failure). Per-hook env: INLINE_SCRIPT_GUARD_PROVIDER (default lu —
## local llama-swap via the `lu` CLI; set =codex to route cloud),
## INLINE_SCRIPT_GUARD_MODEL (default Qwen3.6-35B-A3B),
## INLINE_SCRIPT_GUARD_DECISIONS (comma-separated; e.g. `ask,deny` forbids
## auto-allow structurally; default {allow,deny,ask}). NOTE: these tune only the
## gate-ON adjudicate path; the gate-OFF explain-then-ask flow (`explainScript`
## below) is hardcoded to cloud `llm` and is unaffected by these.
##
## Detection is a yes/no test, not an extraction. Per shell-chaining segment:
## the leading program is `python` / `ruby` (any version suffix) AND the
## segment carries a `-c` / `-e` flag or a `<<` heredoc. Deliberately
## over-eager — a false positive costs one extra confirm; a miss runs an
## unreviewed script.
##
## Wire it up in ~/.claude/settings.json alongside the other Bash guards:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/inline-script-guard"
##
## Deliberately the slow guard: it makes a codex round-trip. Give it no tight
## `timeout` in settings.json — the `llm` call is self-bounded by `timeout(1)`
## below, and inline scripts are rare, so the cost is rare.
##
## Known coverage holes (v1 — separate proposal):
##   1. Bundled short flags — `python3 -Bc '…'` fuses `-c` into `-Bc`. The
##      `\s-[ce]` marker only catches a `-c` / `-e` that follows whitespace.
##   2. Script piped in — `curl … | python3`, `cat x.py | ruby`. The script is
##      not in the command text, so there is nothing to summarize;
##      download-and-run belongs in its own guard.
##   3. Other interpreters — `node -e`, `perl -e`, `php -r`. Same shape; widen
##      `mentionsInterp` / `interpreterToken` when wanted.
##
## Smoke test (paste the payload via /tmp/*.sh — never inline, the test
## payload itself would re-trigger the hook):
##   echo '{"tool_input":{"command":"python3 -c \"import os\""}}' \
##     | inline-script-guard

import std/[json, options, os, osproc, re, streams, strutils]
import ../lib/llm_decide

const LlmTimeoutSecs = "60"
  ## Wall-clock cap on the gate-OFF `explainScript` round-trip, via
  ## `timeout(1)`. codex is slow, but inline scripts are rare; on timeout the
  ## hook degrades to a plain ask.

const
  ContextTurns = 6
  TimeoutSecs = 60 ## gate-ON adjudicate cap (seconds, int).

proc gateOn(): bool =
  getEnv("ALLOW_LLM_DECIDE").len > 0

proc classifierProvider(): string =
  getEnv("INLINE_SCRIPT_GUARD_PROVIDER", "lu")

proc classifierModel(): string =
  # Provider-aware default: local Qwen only when routing to `lu`. A bare
  # INLINE_SCRIPT_GUARD_PROVIDER=codex rollback falls back to "" (codex picks its
  # own model) rather than passing the llama name to codex (→ none → fallback).
  let dflt = if classifierProvider() == "lu": "Qwen3.6-35B-A3B" else: ""
  getEnv("INLINE_SCRIPT_GUARD_MODEL", dflt)

proc allowedDecisions(): seq[string] =
  for part in getEnv("INLINE_SCRIPT_GUARD_DECISIONS", "").split(','):
    let p = part.strip()
    if p.len > 0:
      result.add p

# Fast-path: skip commands that don't mention an interpreter at all.
let mentionsInterp = re"\b(?:python|ruby)"

# Shell-chaining split — the pattern the sibling guards share.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

# Leading `KEY=value` env-var assignments (reused from git-confirm-guard):
# quoted, empty, and backslash-escaped values all handled.
let envAssignPrefix =
  re"""^\s*([A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|(?:\\.|\S)*)\s+)+"""

# A segment whose leading program is an inline interpreter (any version
# suffix: python, python3, python3.12, ruby, ruby3.2).
let interpreterToken = re"^(?:python[0-9.]*|ruby[0-9.]*)(?:\s|$)"

# Inline-script markers inside such a segment: a `-c` / `-e` flag (the
# script's argument may follow the flag directly, so no right boundary), or a
# heredoc / here-string redirect.
let inlineCodeFlag = re"\s-[ce]"
let heredocRedirect = re"<<"

proc hasInlineScript(cmd: string): bool =
  ## True when any shell-chaining segment runs an inline Python/Ruby script.
  for segment in cmd.split(shellChainingSplit):
    let s = segment.strip().replace(envAssignPrefix, "")
    if s.len == 0 or not s.contains(interpreterToken):
      continue
    if s.contains(inlineCodeFlag) or s.contains(heredocRedirect):
      return true
  false

proc timeoutBinary(): string =
  ## GNU coreutils `timeout`, or its Homebrew-prefixed `gtimeout`. "" when
  ## neither is on PATH — the call then runs unwrapped and the Claude Code
  ## hook timeout is the only backstop.
  result = findExe("timeout")
  if result.len == 0:
    result = findExe("gtimeout")

proc explainScript(cmd: string): tuple[ok: bool, raw: string] =
  ## Pipe the whole command to `llm` for a structured summary. `ok` is false on
  ## any failure — non-zero exit, timeout, missing binary — so the caller can
  ## degrade to a plain ask. Used only on the gate-OFF path.
  const llmArgs =
    ["llm", "--schema", "inline-script", "--prompt-file", "inline-script-explain"]
  let tb = timeoutBinary()
  let argv =
    if tb.len > 0:
      @[tb, LlmTimeoutSecs] & @llmArgs
    else:
      @llmArgs
  try:
    let p = startProcess(argv[0], args = argv[1 .. ^1], options = {poUsePath})
    p.inputStream.write(cmd)
    p.inputStream.close()
    let raw = p.outputStream.readAll()
    let code = p.waitForExit()
    p.close()
    (code == 0, raw)
  except CatchableError:
    (false, "")

proc summaryReason(raw: string): string =
  ## Render the model's structured verdict into an ask reason, or "" when the
  ## output can't be parsed into a usable summary.
  var j: JsonNode
  try:
    j = parseJson(raw.strip())
  except CatchableError:
    return ""
  let summary = j{"summary"}.getStr("").strip()
  if summary.len == 0:
    return ""
  var touches: seq[string] = @[]
  if j{"writes_files"}.getBool(false):
    touches.add("writes files")
  if j{"deletes"}.getBool(false):
    touches.add("deletes")
  if j{"network"}.getBool(false):
    touches.add("network access")
  if j{"spawns_processes"}.getBool(false):
    touches.add("spawns processes")
  if j{"reads_sensitive"}.getBool(false):
    touches.add("reads env/credentials")
  result =
    "inline-script-guard: this Bash command runs an inline script.\n\n  " & summary
  if touches.len > 0:
    result &= "\n\n  Touches: " & touches.join(", ") & "."
  else:
    result &=
      "\n\n  No file writes, deletes, network, subprocesses, or credential " &
      "reads were detected."
  let notes = j{"risk_notes"}.getStr("").strip()
  if notes.len > 0:
    result &= "\n\n  Notes: " & notes
  result &=
    "\n\nInline interpreter scripts are opaque to the shell guards — review " &
    "before allowing."

const DegradedReason =
  "inline-script-guard: this Bash command runs an inline Python/Ruby script. " &
  "The automatic explanation was unavailable (the llm call failed or timed " &
  "out). Inline interpreter scripts are opaque to the shell guards — review " &
  "the script yourself before allowing."

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return
  if not cmd.contains(mentionsInterp):
    return # fast path — no interpreter mentioned
  if not hasInlineScript(cmd):
    return # interpreter mentioned, but not as an inline script

  if not gateOn():
    # current behavior: explain, then always ask
    let (ok, raw) = explainScript(cmd)
    if ok:
      let reason = summaryReason(raw)
      if reason.len > 0:
        emit("ask", reason)
        return
    emit("ask", DegradedReason) # detected, but no usable explanation
    return

  # gated: let the model decide allow/ask/deny, summary folded into the reason
  let decision = adjudicate(
    cmd,
    "inline-script-classify",
    provider = classifierProvider(),
    model = classifierModel(),
    transcriptPath = payload{"transcript_path"}.getStr(""),
    contextTurns = ContextTurns,
    allowedDecisions = allowedDecisions(),
    timeoutSecs = TimeoutSecs,
  )
  if decision.isNone:
    emit("ask", DegradedReason)
    return
  let d = decision.get
  emit(d.permissionDecision, d.reason, d.additionalContext)

when isMainModule:
  main()
