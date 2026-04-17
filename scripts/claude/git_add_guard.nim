## Claude Code PreToolUse hook for the `Bash` tool.
##
## Blocks bulk `git add` patterns that stage everything without naming
## files: `-A`, `--all`, `.`, `-u`, `--update`. Goal is to force Claude
## (and humans) to name what they stage, avoiding accidental inclusion
## of secrets, build artifacts, or unrelated changes.
##
## Allowed:
##   git add path/to/file.txt
##   git add path/to/dir/
##   git add -p           # interactive
##
## Blocked:
##   git add -A | --all | . | -u | --update
##
## Wire it up in ~/.claude/settings.json alongside secret-guard:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/git-add-guard"

import std/[json, re]

# Fast-path: only inspect commands that actually invoke `git add`.
let gitAddPrefix = re"\bgit\s+add(\s|$)"

# Bulk-staging arg forms. Trailing `(\s|$)` prevents `--all` from matching
# `--all-hands`, and `.` from matching `.bashrc`.
let bulkStagingArgs =
  re"""(?x)
    \bgit\s+add\s+(
      -A
    | --all
    | \.
    | -u
    | --update
    )(\s|$)
  """

proc deny(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return

  if not cmd.contains(gitAddPrefix):
    return

  if cmd.contains(bulkStagingArgs):
    deny(
      "git-add-guard: bulk staging (-A/--all/./-u/--update) is blocked. " &
        "Name files explicitly (`git add <path>`) or use `git add -p`."
    )
    return

when isMainModule:
  main()
