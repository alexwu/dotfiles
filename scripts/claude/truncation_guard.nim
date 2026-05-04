## Claude Code PreToolUse hook for the `Bash` tool.
##
## Blocks pipelines that truncate diagnostic output via `head` / `tail`,
## and standalone `head FILE` / `tail FILE` file inspections (use the
## Read tool instead). Carve-outs:
##
##   - `tail -f` / `tail --follow` — live following, not truncation
##   - `... | sort [...] | head [-N]` — genuine top-N idiom
##   - `... | sort [...] | tail [-N]` — bottom-N mirror
##
## Why: the useful part of a build/test failure is almost always at the
## end of the output. Truncating with `| head -N` throws it away, and
## the next iteration costs another full simulator boot / test run to
## re-discover what was on screen the first time.
##
## Wire it up in ~/.claude/settings.json alongside secret-guard:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/truncation-guard"
##
## Smoke test (paste payload via /tmp/*.sh, not inline — avoids
## tripping the hook on Claude's own bash invocation):
##   echo '{"tool_input":{"command":"cargo test | head -20"}}' \
##     | truncation-guard

import std/[json, re, strutils]

# Fast-path: skip commands that don't mention head or tail at all.
let mentionsHeadOrTail = re"\b(head|tail)\b"

# Outer split on shell chaining EXCLUDING single `|` — we keep pipes so
# the inner pipeline walk can see stage order (needed for sort | head).
# `||` is split here too (we don't analyze across short-circuit OR).
let outerSplit = re"""[;&`\n]+|\$\(|\|\|"""

# Per-segment leading-token detection.
let leadingHeadOrTail = re"^(head|tail)(\s|$)"
let leadingTail = re"^tail(\s|$)"
let leadingSort = re"^sort(\s|$)"

# `tail -f` / `tail -F` / `tail --follow` — short flag (incl. combined
# like -nf, -fF, -f10) or long form. Anywhere in tail's args.
let tailFollowFlag = re"\s-[a-zA-Z]*[fF][a-zA-Z0-9]*\b|\s--follow(=|\s|$)"

proc deny(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

proc analyzePipeline(pipeline: string): tuple[deny: bool, reason: string] =
  let stages = pipeline.split('|')
  for i in 0 .. stages.high:
    let stage = stages[i].strip()
    if not stage.contains(leadingHeadOrTail):
      continue

    # Allow `tail -f` / `tail --follow` (live follow, not truncation).
    if stage.contains(leadingTail) and stage.contains(tailFollowFlag):
      continue

    # Allow when the previous pipeline stage is `sort ...` (top-N idiom).
    if i > 0 and stages[i - 1].strip().contains(leadingSort):
      continue

    let kind = if stage.contains(leadingTail): "tail" else: "head"
    return (
      true,
      "truncation-guard: NO. `" & stage & "` truncates `" & kind & "` " &
        "output. You keep doing this — every session, every time. The " &
        "useful part of build/test failures is at the END; truncated " &
        "output is useless output. Re-run WITHOUT the `" & kind & "` and " &
        "read the full stream inline. No `> /tmp/foo` workaround. " &
        "Read the whole thing.\n\n" &
        "Alex has asked you to stop reaching for the shortcut. Listen to " &
        "him.\n\nAllowed: `tail -f` (live follow), " &
        "`... | sort | head/tail` (top-N idiom). That's it.",
    )
  return (false, "")

proc main() =
  let payload = parseJson(stdin.readAll())
  let raw = payload{"tool_input", "command"}.getStr("")
  if raw.len == 0:
    return
  if not raw.contains(mentionsHeadOrTail):
    return # fast path

  # Collapse shell line-continuations BEFORE the outer split so that
  # multi-line `... | sort -rh \<NL>| head -5` stays one pipeline and
  # the sort-exception still applies. Without this, `\n` in outerSplit
  # would chop the pipeline at the backslash-newline.
  let cmd = raw.replace("\\\n", " ").replace("\\\r\n", " ")

  for compound in cmd.split(outerSplit):
    let (shouldDeny, reason) = analyzePipeline(compound)
    if shouldDeny:
      deny(reason)
      return

when isMainModule:
  main()
