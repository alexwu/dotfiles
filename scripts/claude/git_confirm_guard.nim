## Claude Code PreToolUse hook for the `Bash` tool.
##
## Forces an explicit `ask` decision for any segment that runs
## `git commit` or `git push`. These rewrite shared/published state, so
## every one should surface a confirmation prompt — including chained
## forms (`git commit -m "…" && git push`), which would otherwise blob
## into a single hard-to-read prompt.
##
## Pass-through:
##   git status / git log / git diff / git add <path> / etc.
##
## Always asks:
##   git commit -m "…"
##   git push
##   git push --force-with-lease origin main
##   git commit -m "…" && git push       # both segments listed in reason
##
## Known miss: `git -C <dir> commit` — the leading-token regex assumes
## `git` is followed directly by the subcommand. Acceptable: Claude
## rarely uses `git -C`, and the worst case is the default permission
## flow handles the prompt instead of this hook's nicer reason text.
##
## Wire it up in ~/.claude/settings.json alongside the other Bash guards:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/git-confirm-guard"
##
## Smoke test (paste payload via /tmp/*.sh — never inline, the test
## payload itself would re-trigger the hook):
##   echo '{"tool_input":{"command":"git push"}}' | git-confirm-guard

import std/[json, re, strutils]

# Fast-path: skip commands that don't mention these subcommands at all.
let mentionsCommitOrPush = re"\bgit\s+(commit|push)\b"

# Same chaining-split pattern as secret-guard. Per-segment leading-token
# checks below ignore anything that isn't `git commit` / `git push`, so
# we don't need true shell parsing.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

# Per-segment leading-token detection. Trailing `(\s|$)` prevents
# `git commit-tree` / `git push-options` from matching.
let leadingCommitOrPush = re"^git\s+(commit|push)(\s|$)"

proc askDecision(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return
  if not cmd.contains(mentionsCommitOrPush):
    return # fast path

  var matched: seq[string] = @[]
  for segment in cmd.split(shellChainingSplit):
    let s = segment.strip()
    if s.contains(leadingCommitOrPush):
      matched.add("`" & s & "`")

  if matched.len == 0:
    return

  let label = if matched.len == 1: "segment" else: "segments"
  askDecision(
    "git-confirm-guard: confirm before running git " & label & ": " &
      matched.join(", ") & ". " &
      "git commit and git push always require explicit approval."
  )

when isMainModule:
  main()
