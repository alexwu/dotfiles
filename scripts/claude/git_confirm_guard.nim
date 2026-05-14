## Claude Code PreToolUse hook for the `Bash` tool.
##
## Forces an explicit `ask` decision for git operations that rewrite history,
## destroy local state, push force, or otherwise mutate the repo in ways
## that should always be visible to the user. Extends the original commit/
## push-only coverage to the full set of destructive verbs.
##
## ┌─────────────────────────────────────────────────────────────────────┐
## │ PREREQUISITE — the wiring in claude-settings.json must NOT use a    │
## │ narrow `if: "Bash(git *)"` filter, or env-prefixed forms like       │
## │     GIT_SEQUENCE_EDITOR=/tmp/x git rebase -i HEAD~3                 │
## │ will skip this hook entirely (leading token is `GIT_SEQUENCE_EDITOR=│
## │ `, not `git`). Drop the `if` filter; the mentionsGit fast-path      │
## │ below makes the binary cheap on non-git commands anyway.            │
## └─────────────────────────────────────────────────────────────────────┘
##
## Two tiers, both return permissionDecision: "ask" (not "deny"):
##
##   Tier 1 — always ask (no safe form):
##     rebase, filter-branch, filter-repo
##
##   Universal — any git subcommand carrying a standalone `--force` flag.
##   Catches force on subcommands not enumerated below (filter-repo,
##   checkout -f counterpart `--force`, branch --force, tag --force, etc.).
##   Word-boundary on the right is `\s|$|=`, so the safer `--force-with-lease`
##   form is NOT caught here (it's gated by the push-specific pattern below).
##
##   Tier 2 — ask only with destructive flag/arg:
##     reset --hard
##     stash drop | clear | pop
##     stash push -u|--include-untracked|-a|--all
##     stash save -u|--include-untracked|-a|--all   (legacy form)
##     branch -d|-D|--delete
##     checkout -- <path> | checkout .
##     restore (any form — destructive unless --staged-only, FP OK)
##     clean (any form — only -n is safe and rare in scripts)
##     push --force | --force-with-lease[=<ref>] | -f
##     push <remote> +<refspec>                     (force-push shorthand)
##     reflog expire | delete | clear
##     update-ref -d | --stdin                      (stdin payload can delete)
##     tag -d | --delete
##     worktree remove | prune
##     replace                                       (rewrites refs)
##     notes prune | remove
##     submodule deinit                              (with -f loses local mods)
##     remote remove | remote rm
##     config --unset                                (can wipe required keys)
##     symbolic-ref -d
##     rerere clear | forget | gc
##
##   Carry-over from the original version: commit, push (any form).
##
## Env-var-prefix handling — `KEY=value [KEY2=value2] git <verb>` is
## stripped before the leading-token regex. Quoted (`KEY="hello world"`),
## empty (`KEY=`), and backslash-escaped values (`KEY=hello\ world`) all
## handled. Bare unquoted unescaped values containing spaces are NOT shell-
## valid in this position, so not a concern.
##
## Pass-through:
##   git status / log / diff / show / blame / add <path> / fetch /
##   pull --ff-only / branch (list) / tag (list) / stash list / stash show /
##   worktree list / cherry-pick / revert  (constructive; add new commits)
##   git restore --staged <path>           (only unstages; ASKED anyway — minor FP)
##
## Known coverage holes (NOT addressed here — separate proposal):
##   1. Script-write-then-bash: cat > /tmp/x.sh; bash /tmp/x.sh
##      The hook sees `bash /tmp/x.sh` at exec time, not the script body.
##      A sibling hook could ask when ONE Bash call contains BOTH
##      `chmod +x /tmp/...` AND `/tmp/...` execution.
##   2. `git -C <dir> <verb>` — leading-token regex assumes `git` is
##      followed directly by the subcommand. Acceptable: rare in practice.
##   3. `eval "$cmd"` / base64-decoded payloads / heredoc-bodies invoked
##      via a subsequent Bash call — out of scope for static-string match.
##
## Wire it up in ~/.claude/settings.json alongside the other Bash guards:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/git-confirm-guard"
##   (NO `if` filter — see PREREQUISITE above.)
##
## Smoke test (paste payload via /tmp/*.sh — never inline, the test
## payload itself would re-trigger the hook):
##   echo '{"tool_input":{"command":"GIT_SEQUENCE_EDITOR=x git rebase -i HEAD~3"}}' \
##     | git-confirm-guard

import std/[json, re, strutils]

# Fast-path: skip commands that don't mention `git` anywhere.
let mentionsGit = re"\bgit\b"

# Strip leading `KEY=value` env-var assignments (possibly multiple).
# Handles: quoted ("..."/'...'), empty (FOO=), backslash-escaped (FOO=a\ b).
# Does NOT handle bare unquoted values with literal spaces (shell-invalid).
let envAssignPrefix =
  re"""^\s*([A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|(?:\\.|\S)*)\s+)+"""

# Same chaining-split pattern as secret-guard.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

# Tier 1: verb alone is enough to ask.
let tier1Verbs = re"""^git\s+(rebase|filter-branch|filter-repo)(\s|$)"""

# Carry-over from the original commit/push-only version.
let commitPush = re"""^git\s+(commit|push)(\s|$)"""

# Universal --force guard — any git subcommand with a standalone `--force`
# flag (filter-repo, filter-branch, branch, tag, checkout, clean, …) asks.
# Word boundary on the right is `\s|$|=` so `--force-with-lease` does NOT
# match here (the safer form is still gated by the push-specific pattern).
let forceFlag = re"""^git\s+.*\s--force(\s|$|=)"""

# Tier 2: destructive flag/arg combinations on otherwise-safe verbs.
# False-positive cost = one extra confirm; we err on the side of asking.
let tier2Patterns = [
  # reset --hard (discards worktree/index)
  re"""^git\s+reset\s+(.*\s)?--hard\b""",

  # stash operations
  re"""^git\s+stash\s+(drop|clear|pop)(\s|$)""",
  re"""^git\s+stash\s+push\s+(.*\s)?(-u|--include-untracked|-a|--all)(\s|$)""",
  re"""^git\s+stash\s+save\s+(.*\s)?(-u|--include-untracked|-a|--all)(\s|$)""",

  # branch deletion (short and long forms)
  re"""^git\s+branch\s+(.*\s)?(-[dD]|--delete)(\s|$)""",

  # checkout discarding worktree changes
  re"""^git\s+checkout\s+(--|\.)(\s|$)""",

  # restore — virtually always destructive unless --staged-only;
  # we ask on all forms to avoid an under-match.
  re"""^git\s+restore(\s|$)""",

  # clean — only -n is safe; ask on all
  re"""^git\s+clean(\s|$)""",

  # force push (multiple flag forms)
  re"""^git\s+push\s+.*(\s)(--force|--force-with-lease(=\S+)?|-f)(\s|$)""",
  # +refspec push shorthand (e.g., `git push origin +master`)
  re"""^git\s+push\s+.*\s\+\S+""",

  # reflog destruction
  re"""^git\s+reflog\s+(expire|delete|clear)(\s|$)""",

  # low-level ref deletion / scripted deletes via stdin
  re"""^git\s+update-ref\s+(.*\s)?-d\b""",
  re"""^git\s+update-ref\s+(.*\s)?--stdin(\s|$)""",

  # tag deletion (short and long)
  re"""^git\s+tag\s+(.*\s)?(-d|--delete)(\s|$)""",

  # worktree management
  re"""^git\s+worktree\s+(remove|prune)(\s|$)""",

  # broader destructive verbs
  re"""^git\s+replace\b""",
  re"""^git\s+notes\s+(prune|remove)(\s|$)""",
  re"""^git\s+submodule\s+deinit\b""",
  re"""^git\s+remote\s+(remove|rm)(\s|$)""",
  re"""^git\s+config\s+(.*\s)?--unset\b""",
  re"""^git\s+symbolic-ref\s+(.*\s)?-d\b""",
  re"""^git\s+rerere\s+(clear|forget|gc)(\s|$)""",
]

proc askDecision(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

proc stripEnvPrefix(segment: string): string =
  ## Remove leading `KEY=value` env-var assignments so e.g.
  ## `GIT_SEQUENCE_EDITOR=/tmp/x git rebase -i HEAD~3` parses leading-token
  ## as `git`. Idempotent: returns segment unchanged if no env-prefix.
  segment.replace(envAssignPrefix, "")

proc segmentRisk(segment: string): string =
  ## Returns a short risk label if this segment is risky, "" otherwise.
  let s = stripEnvPrefix(segment.strip())
  if s.contains(tier1Verbs):
    return "rewrites history"
  if s.contains(commitPush):
    return "publishes / records state"
  if s.contains(forceFlag):
    return "--force flag"
  for pat in tier2Patterns:
    if s.contains(pat):
      return "destructive flag/arg"
  return ""

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return
  if not cmd.contains(mentionsGit):
    return # fast path — no git verb anywhere

  var matched: seq[string] = @[]
  for segment in cmd.split(shellChainingSplit):
    let s = segment.strip()
    if s.len == 0:
      continue
    let risk = segmentRisk(s)
    if risk.len > 0:
      let stripped = stripEnvPrefix(s)
      matched.add("`" & stripped & "` (" & risk & ")")

  if matched.len == 0:
    return

  let label = if matched.len == 1: "segment" else: "segments"
  askDecision(
    "git-confirm-guard: confirm before running git " & label & ": " & matched.join(", ") &
      ". These rewrite history, destroy local state, or publish to remote " &
      "— every one requires explicit approval."
  )

when isMainModule:
  main()
