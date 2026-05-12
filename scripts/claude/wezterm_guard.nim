## Claude Code PreToolUse hook for the `Bash` tool.
##
## Forces an explicit `ask` decision before `wezterm cli kill-pane` (and any
## future `wezterm cli kill-*` subcommand). `kill-pane` destroys a pane
## immediately with no prompt, and when invoked WITHOUT `--pane-id` it targets
## the *current* pane — so a bare `wezterm cli kill-pane`, run from inside a
## WezTerm pane, kills Claude Code's own shell.
##
## Runs on every Bash command regardless of whether the `wezterm-cli` skill is
## loaded — a standing safety net, the same as truncation-guard / secret-guard /
## git-confirm-guard. Returns permissionDecision: "ask" (not "deny"): there are
## legitimate reasons to close a pane; the point is that it must be explicit.
##
## Detection: split the command on shell chaining (`|`, `;`, `&`, backtick,
## `$(`, newline); for each segment, strip leading `KEY=value` env-var
## assignments, then ask when the segment's leading program is `wezterm` AND it
## contains a `cli` token AND a `kill-<word>` token. False-positive cost is one
## extra confirm — err on the side of asking.
##
## Wire it up in claude-settings.json alongside the other Bash guards:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/wezterm-guard"
##   (NO `if` filter — the mentionsWezterm fast-path keeps the binary cheap on
##   non-wezterm commands, and an `if: "Bash(wezterm *)"` filter would skip
##   env-prefixed forms like `FOO=bar wezterm cli kill-pane`.)
##
## Smoke test (paste payload via /tmp/*.sh, never inline — an inline payload
## containing `wezterm cli kill-pane` re-triggers the hook on Claude's own bash):
##   echo '{"tool_input":{"command":"wezterm cli kill-pane --pane-id 3"}}' \
##     | wezterm-guard

import std/[json, re, strutils]

# Fast-path: skip commands that never mention wezterm.
let mentionsWezterm = re"\bwezterm\b"

# Strip leading `KEY=value` env-var assignments (quoted / empty / backslash-escaped).
# Same pattern as git-confirm-guard.
let envAssignPrefix =
  re"""^\s*([A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|(?:\\.|\S)*)\s+)+"""

# Same chaining split as the sibling Bash guards.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

# Segment must start with the `wezterm` program (after env-strip).
let leadingWezterm = re"^wezterm(\s|$)"

# ...and somewhere carry a `cli` subcommand and a `kill-<word>` subcommand.
# `kill-[a-z]+` covers `kill-pane` today and any future `kill-tab` / `kill-window`.
let cliWord = re"\bcli\b"
let killSubcommand = re"\bkill-[a-z]+\b"

proc askDecision(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

proc strippedSegment(segment: string): string =
  segment.strip().replace(envAssignPrefix, "")

proc isRiskyWeztermKill(segment: string): bool =
  let s = strippedSegment(segment)
  s.contains(leadingWezterm) and s.contains(cliWord) and s.contains(killSubcommand)

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return
  if not cmd.contains(mentionsWezterm):
    return # fast path — no wezterm anywhere

  var matched: seq[string] = @[]
  for segment in cmd.split(shellChainingSplit):
    if segment.strip().len == 0:
      continue
    if isRiskyWeztermKill(segment):
      matched.add("`" & strippedSegment(segment) & "`")

  if matched.len == 0:
    return

  let label = if matched.len == 1: "command" else: "commands"
  askDecision(
    "wezterm-guard: confirm before running destructive WezTerm " & label & ": " &
      matched.join(", ") & ". `kill-pane` destroys a pane immediately with no " &
      "prompt; without `--pane-id` it kills the *current* pane — which is Claude " &
      "Code's own shell when it runs inside WezTerm. Only proceed if closing a " &
      "pane is exactly what was requested."
  )

when isMainModule:
  main()
