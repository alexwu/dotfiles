## Claude Code PreToolUse hook for the `Bash` tool.
##
## Blocks commands that truncate diagnostic output via `head` / `tail` when
## the upstream is expensive (build, test, network, container ops). Allows
## truncation when the upstream is cheap (CLI help, listings, search results,
## small file reads). The decision goes through the shared
## `llm_decide.adjudicate` (default: local `lu` provider, Qwen3.6-35B-A3B)
## against the strict PreToolUse schema — the prompt at `truncation-classify`
## encodes the cheap/expensive taxonomy and tells the model to deny by default.
##
## Why an LLM and not regex: every regex carve-out we ship breeds the next
## "but my command is special" excuse. The reflex to truncate `cargo test`,
## `pytest`, or a `curl` payload is what the guard exists to interrupt;
## handing the decision to a small fast model removes the bypass surface that
## a regex policy invites and lets the prompt evolve without a redeploy.
##
## Always-on (NOT gated on ALLOW_LLM_DECIDE) — classification is this hook's
## whole job. Fail-closed: a missing / errored / unparseable classifier
## response (adjudicate → none) degrades to `deny` with a memo recommendation,
## not allow. The reward contract here is "no truncation without proof it's
## cheap"; an unavailable classifier is no proof.
##
## Tunable via env: TRUNCATION_GUARD_PROVIDER (default lu — local llama-swap via
## the `lu` CLI; this guard is always-on, so the default switches the live
## classifier dependency to the local model. Set =codex to route cloud, e.g. on
## a machine without the llama-swap stack), TRUNCATION_GUARD_MODEL (default
## Qwen3.6-35B-A3B), TRUNCATION_GUARD_DECISIONS (comma-separated; default
## {allow,deny,ask}).
##
## Wire it up in ~/.claude/settings.json alongside the other Bash guards:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/truncation-guard"
##
## Cost: one classifier round-trip every time `head` or `tail` appears in a Bash
## command (fast on the resident local model). Most commands never mention either
## word, so the fast-path skips them outright.
##
## Smoke test (paste payload via /tmp/*.sh, not inline — avoids tripping the
## hook on Claude's own bash invocation):
##   echo '{"tool_input":{"command":"cargo test | head -20"}}' \
##     | truncation-guard

import std/[json, options, os, re, strutils]
import ../lib/llm_decide

const TimeoutSecs = 30
  ## Wall-clock cap on the classifier round-trip via `timeout(1)`. The default
  ## local model is resident (always-on group), so 30s is ample; it also leaves
  ## headroom if routed to a cloud provider. On timeout the hook degrades to a deny.

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

proc classifierProvider(): string =
  getEnv("TRUNCATION_GUARD_PROVIDER", "lu")

proc classifierModel(): string =
  # Provider-aware default: local Qwen only when routing to `lu`. Critical for
  # the documented rollback — a bare TRUNCATION_GUARD_PROVIDER=codex must fall
  # back to "" (codex picks its own model). Otherwise the llama model name would
  # reach codex → error → none → this always-on guard denies EVERY head/tail.
  let dflt = if classifierProvider() == "lu": "Qwen3.6-35B-A3B" else: ""
  getEnv("TRUNCATION_GUARD_MODEL", dflt)

proc allowedDecisions(): seq[string] =
  for part in getEnv("TRUNCATION_GUARD_DECISIONS", "").split(','):
    let p = part.strip()
    if p.len > 0:
      result.add p

const DegradedReason =
  "truncation-guard: the classifier was unavailable (failed, timed " &
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

  let decision = adjudicate(
    cmd,
    "truncation-classify",
    provider = classifierProvider(),
    model = classifierModel(),
    contextTurns = 0,
    allowedDecisions = allowedDecisions(),
    timeoutSecs = TimeoutSecs,
  )
  if decision.isNone:
    emit("deny", DegradedReason)
    return
  let d = decision.get
  emit(d.permissionDecision, d.reason, d.additionalContext)

when isMainModule:
  main()
