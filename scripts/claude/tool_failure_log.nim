## Claude Code PostToolUseFailure hook (matcher: Bash).
##
## Appends failing lulu-tools invocations (memo/chain/tokens/schema/speak/
## mosaic/image/hark) to a durable JSONL log so friction history survives
## Claude Code's transcript retention window. The `skills/eval-tools` skill in
## ~/Code/lulu-tools mines this log alongside the transcripts.
##
## Observe-only and fail-open: every exception path exits 0. Logging must never
## disturb a session, so a broken log write is silent by design — the miner
## cross-checks against transcripts anyway.
##
## Payload shape verified empirically 2026-07-16 (the docs were wrong twice):
##   {"session_id", "cwd", "hook_event_name": "PostToolUseFailure",
##    "tool_name": "Bash", "tool_input": {"command"}, "tool_use_id": "toolu_…",
##    "error": "Exit code 1\n<full stderr>", "is_interrupt": false,
##    "duration_ms": 38}
## NOTE: the failure text is `error`, NOT `tool_error` as the hooks doc claims —
## reading `tool_error` yields "" and looks like a working hook logging blanks.
##
## `is_interrupt: true` means the user cancelled the command. That is not tool
## friction, so those are dropped.
##
## Wire it up in ~/.claude/settings.json alongside the other Bash hooks:
##   hooks.PostToolUseFailure[].matcher = "Bash"
##   hooks.PostToolUseFailure[].hooks[].command = "$HOME/.local/bin/tool-failure-log"
##
## Smoke test (throwaway state dir so the real log stays clean):
##   echo '{"tool_name":"Bash","tool_input":{"command":"memo x"},"error":"boom"}' \
##     | XDG_STATE_HOME=$(mktemp -d) tool-failure-log

import std/[json, os, re, times]

const MaxErrorChars = 400
  ## Failure text is capped so one pathological stderr can't bloat the log.
  ## The transcript still holds the full text if the miner ever needs it.

# Leading program match: env-var prefixes stripped (quoted/escaped values
# handled — same pattern as envAssignPrefix in truncation_guard.nim:72),
# multiline so `cd x\nmemo …` still matches. Known limitation: a tool name at
# the start of a heredoc/quoted line can false-positive; the miner's judgment
# layer discards those, and the fixtures pin the common cases.
#
# WARNING: the multiline mode MUST come from the inline `(?m)`, not from std/re's
# `{reMultiLine}` flag — that flag is silently a no-op (verified 2026-07-16:
# `re(r"^memo", {reMultiLine})` does not match "cd /x\nmemo", while `(?m)^memo`
# matches at index 6). Passing the flag compiles and looks correct while never
# matching a second line. Do not "clean this up" into the flag form.
let toolRe = re(
  r"""(?m)^\s*(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|(?:\\.|\S)*)\s+)*""" &
    r"""(memo|chain|tokens|schema|speak|mosaic|image|hark)\b"""
)

proc isToolInvocation*(cmd: string): bool =
  ## True when the command's leading program (any line) is a lulu-tool.
  ## Exported for the fixtures in test_tool_failure_log.nim.
  cmd.contains(toolRe)

proc logPath*(): string =
  ## Mirrors the XDG convention in crates/hark/src/paths.rs: $XDG_STATE_HOME
  ## when set and non-empty, else ~/.local/state.
  let xdg = getEnv("XDG_STATE_HOME")
  let base =
    if xdg.len > 0:
      xdg
    else:
      getHomeDir() / ".local" / "state"
  base / "lulu-tools" / "tool-failures.jsonl"

proc main() =
  let payload = parseJson(stdin.readAll())
  if payload{"tool_name"}.getStr("") != "Bash":
    return
  if payload{"is_interrupt"}.getBool(false):
    return # user cancelled — not tool friction
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0 or not isToolInvocation(cmd):
    return
  let err = payload{"error"}.getStr("")
  let rec = %*{
    "ts": now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    "session": payload{"session_id"}.getStr(""),
    "tool_use_id": payload{"tool_use_id"}.getStr(""),
    "cwd": payload{"cwd"}.getStr(""),
    "cmd": cmd,
    "error": err[0 ..< min(MaxErrorChars, err.len)],
  }
  createDir(logPath().parentDir)
  let f = open(logPath(), fmAppend)
  defer:
    f.close()
  f.writeLine $rec

when isMainModule:
  try:
    main()
  except CatchableError:
    discard # fail-open: logging must never disturb the session
