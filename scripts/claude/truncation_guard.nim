## Claude Code PreToolUse hook for the `Bash` tool.
##
## Blocks commands that truncate diagnostic output via `head` / `tail` when
## the upstream is expensive (build, test, network, container ops). Allows
## truncation when the upstream is cheap (CLI help, listings, search results,
## small file reads). The decision is made by `llm` (codex provider, spark
## model) against the strict PreToolUse schema — the prompt at
## `truncation-classify` encodes the cheap/expensive taxonomy and tells the
## model to deny by default.
##
## Why an LLM and not regex: every regex carve-out we ship breeds the next
## "but my command is special" excuse. The reflex to truncate `cargo test`,
## `pytest`, or a `curl` payload is what the guard exists to interrupt;
## handing the decision to a small fast model removes the bypass surface that
## a regex policy invites and lets the prompt evolve without a redeploy.
##
## Fail-closed: a missing / errored / unparseable `llm` response degrades to
## `deny` with a memo recommendation, not allow. The reward contract here is
## "no truncation without proof it's cheap"; an unavailable classifier is no
## proof.
##
## Wire it up in ~/.claude/settings.json alongside the other Bash guards:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/truncation-guard"
##
## Cost: one spark round-trip (typically 2-4s) every time `head` or `tail`
## appears in a Bash command. Most commands never mention either word, so the
## fast-path skips them outright.
##
## Smoke test (paste payload via /tmp/*.sh, not inline — avoids tripping the
## hook on Claude's own bash invocation):
##   echo '{"tool_input":{"command":"cargo test | head -20"}}' \
##     | truncation-guard

import std/[json, os, osproc, re, streams, strutils]

const LlmTimeoutSecs = "30"
  ## Wall-clock cap on the `llm` round-trip via `timeout(1)`. Spark is fast;
  ## 30s is enough headroom for a cold start on a slow link without holding
  ## the Bash call hostage. On timeout the hook degrades to a deny.

# Fast-path: skip commands that don't mention head or tail at all.
let mentionsHeadOrTail = re"\b(head|tail)\b"

# `memo <cmd>` runs `<cmd>` and caches its full stdout/stderr; the
# `--head N` / `--tail N` flags only bound the *display*, never the
# cached stream. So a memo invocation is the opposite of truncation —
# it's the recommended non-evasive replacement we tell people to use.
# Match it at the fast-path level so we don't waste a classifier
# round-trip just to land back at "use memo".
let leadingMemo = re"^memo(\s|$)"

# Leading `KEY=value` env-var prefixes — reused from sibling guards so
# `MEMO=1 memo …` and `FOO=bar memo …` still get carved out.
let envAssignPrefix =
  re"""^\s*([A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|(?:\\.|\S)*)\s+)+"""

proc timeoutBinary(): string =
  ## GNU coreutils `timeout`, or its Homebrew-prefixed `gtimeout`. "" when
  ## neither is on PATH — the call then runs unwrapped and the Claude Code
  ## hook timeout is the only backstop.
  result = findExe("timeout")
  if result.len == 0:
    result = findExe("gtimeout")

proc classify(cmd: string): tuple[ok: bool, raw: string] =
  ## Pipe the whole command to `llm` for a PreToolUse-shaped decision. `ok`
  ## is false on any failure — non-zero exit, timeout, missing binary — so
  ## the caller can degrade to a deny.
  const llmArgs = [
    "llm",
    "--model",
    "gpt-5.3-codex-spark",
    "--schema",
    "strict/pretooluse",
    "--promptFile",
    "truncation-classify",
  ]
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

proc stripNulls(node: JsonNode) =
  ## The strict schema types optional fields as nullable; the model emits null
  ## when not applicable and the per-schema convention is to strip null keys
  ## before forwarding to the hook consumer.
  if node.kind != JObject:
    return
  var keysToDrop: seq[string]
  for k, v in node.pairs:
    case v.kind
    of JNull:
      keysToDrop.add(k)
    of JObject:
      stripNulls(v)
    else:
      discard
  for k in keysToDrop:
    node.delete(k)

proc emitDeny(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

const DegradedReason =
  "truncation-guard: the spark classifier was unavailable (failed, timed " &
  "out, or returned an unparseable response), so this is failing closed. " &
  "If the upstream is genuinely cheap (--help, rg, ls, cat, git log), " &
  "re-run without `head` / `tail`. If it's expensive (build, test, network, " &
  "container), use `memo <cmd> --tail N` instead — memo caches the full " &
  "output so it can be re-read via `memo show -- <cmd>`, no information lost."

proc isMemoInvocation(cmd: string): bool =
  ## True when the command's leading program is `memo` (env-prefixes
  ## stripped first). Treat memo as always-allowed truncation since its
  ## `--head` / `--tail` flags don't discard the underlying stream.
  let stripped = cmd.strip().replace(envAssignPrefix, "")
  stripped.contains(leadingMemo)

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return
  if not cmd.contains(mentionsHeadOrTail):
    return # fast path — no head/tail mentioned at all
  if isMemoInvocation(cmd):
    return # memo wraps full output in cache; --head/--tail are display only

  let (ok, raw) = classify(cmd)
  if not ok:
    emitDeny(DegradedReason)
    return

  var j: JsonNode
  try:
    j = parseJson(raw.strip())
  except CatchableError:
    emitDeny(DegradedReason)
    return

  stripNulls(j)

  # Defensive: if the model emits something that isn't a recognized decision,
  # treat it as a classifier failure and fall back to deny.
  let decision = j{"hookSpecificOutput", "permissionDecision"}.getStr("")
  if decision notin ["allow", "deny", "ask"]:
    emitDeny(DegradedReason)
    return

  echo j

when isMainModule:
  main()
