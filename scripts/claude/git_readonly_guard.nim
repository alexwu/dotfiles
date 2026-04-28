## Claude Code PreToolUse hook for the `Bash` tool, scoped via subagent
## frontmatter to `code-explorer`. Allows only read-only `git` verbs;
## passes through non-git commands unchanged.
##
## Read-only verbs allowed:
##   log, diff, show, blame, status, reflog, shortlog, grep,
##   ls-files, ls-tree, cat-file,
##   rev-parse, rev-list, describe, name-rev, merge-base
##
## Any other `git <verb>` is denied. Non-git commands (eza, tree, find,
## rg, etc.) pass through unchecked — code-explorer's tools allowlist is
## already tight (Read/Grep/Glob/Bash) and secret-guard handles
## sensitive-path reads at the global PreToolUse layer.
##
## Wire it up in a subagent's frontmatter `hooks` block:
##   hooks:
##     PreToolUse:
##       - matcher: "Bash"
##         hooks:
##           - type: command
##             command: "$HOME/.local/bin/git-readonly-guard"

import std/[json, re, strutils]

let gitInvocation = re"^\s*git(\s|$)"

let readOnlyVerbs =
  re"""(?x)
    ^\s*git\s+(
      log
    | diff
    | show
    | blame
    | status
    | reflog
    | shortlog
    | grep
    | ls-files
    | ls-tree
    | cat-file
    | rev-parse
    | rev-list
    | describe
    | name-rev
    | merge-base
    )(\s|$)
  """

# Shell chaining split-points: pipe, semicolon, ampersand, backtick,
# command substitution, newline. Mirrors secret_guard.nim — we check
# each segment independently so `true && git push` doesn't sneak past
# a regex that anchors to start-of-string.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

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

  for segment in cmd.split(shellChainingSplit):
    if not segment.contains(gitInvocation):
      continue # non-git segment, skip

    if segment.contains(readOnlyVerbs):
      continue # allowed read-only verb in this segment

    deny(
      "git-readonly-guard: `" & segment.strip() &
        "` is not in the read-only git allowlist " &
        "(log/diff/show/blame/status/reflog/shortlog/grep/ls-*/cat-file/rev-*/describe/name-rev/merge-base)"
    )
    return

when isMainModule:
  main()
