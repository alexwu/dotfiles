## Claude Code PreToolUse hook for the `Bash` tool.
##
## Forces an explicit `ask` decision for git operations that rewrite history,
## destroy local state, push force, or otherwise mutate the repo in ways
## that should always be visible to the user. Extends the original commit/
## push-only coverage to the full set of destructive verbs.
##
## LLM-decide gate: with ALLOW_LLM_DECIDE set, a flagged command is handed to
## the shared `llm_decide.adjudicate` (with recent UNTRUSTED conversation as
## context) which may return allow / ask / deny — so a destructive op the user
## just authorized can skip the prompt. The static detection below stays as the
## cheap pre-filter: the model only ever adjudicates a command this guard
## already flagged. Gate UNSET → the static `ask` below, exactly as before.
## Classifier unavailable (adjudicate → none) → the static `ask` (never a
## silent allow on failure). Per-hook env: GIT_CONFIRM_GUARD_PROVIDER (default
## lu — local llama-swap via the `lu` CLI; set =codex to route cloud),
## GIT_CONFIRM_GUARD_MODEL (default Qwen3.6-35B-A3B),
## GIT_CONFIRM_GUARD_DECISIONS (comma-separated; e.g. `ask,deny` forbids
## auto-allow structurally; default {allow,deny,ask}).
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
##     rm (any form — removes tracked files from the worktree and index)
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
##   The three carry-overs now land in different tiers:
##     commit --amend   catastrophic — rewrites the last commit; the local half
##                      of amend-then-force-push, and force-push is already
##                      catastrophic. Enum drops `allow`; always at least asks.
##     commit (plain)   softened — still detected and adjudicated (the reason is
##                      worth having in the transcript), but the enum drops
##                      `deny`, so a routine commit can cost at most one confirm.
##                      Revoked by a risky sibling segment or an AST-only match.
##     push             unchanged — detected, fully adjudicable; the destructive
##                      push forms remain catastrophic on their own patterns.
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

import std/[json, options, os, re, sequtils, strutils, tables]
import ../lib/llm_decide
import ../lib/ast_bash
import ast_guard_rules

const
  ContextTurns = 6
  TimeoutSecs = 30

proc gateOn(): bool =
  getEnv("ALLOW_LLM_DECIDE").len > 0

proc classifierProvider(): string =
  getEnv("GIT_CONFIRM_GUARD_PROVIDER", "lu")

proc classifierModel(): string =
  # Provider-aware default: the local Qwen only when routing to `lu`. A bare
  # GIT_CONFIRM_GUARD_PROVIDER=codex rollback must NOT inherit the llama model
  # name (codex would reject it → none → fallback); fall back to "" so the cloud
  # provider picks its own default.
  let dflt = if classifierProvider() == "lu": "Qwen3.6-35B-A3B" else: ""
  getEnv("GIT_CONFIRM_GUARD_MODEL", dflt)

proc allowedDecisions(): seq[string] =
  for part in getEnv("GIT_CONFIRM_GUARD_DECISIONS", "").split(','):
    let p = part.strip()
    if p.len > 0:
      result.add p

# Fast-path: skip commands that don't mention `git` anywhere.
let mentionsGit = re"\bgit\b"

# Strip leading `KEY=value` env-var assignments (possibly multiple).
# Handles: quoted ("..."/'...'), empty (FOO=), backslash-escaped (FOO=a\ b).
# Does NOT handle bare unquoted values with literal spaces (shell-invalid).
let envAssignPrefix =
  re"""^\s*([A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|(?:\\.|\S)*)\s+)+"""

# Normalization for matching (closes two red-team holes). dequoteFlag unwraps a
# quoted flag (`"--force"` → `--force`) so a quote can't hide it from the flag
# patterns. gitGlobalOpts matches a `git <global-opts>` prefix so `git -C <dir>
# <verb>` / `-c k=v` / `--git-dir …` can be re-anchored to `git <verb>` (those
# options otherwise slide the verb past the `^git\s+<verb>` anchor entirely —
# a destructive op would pass UNGUARDED). Best-effort, NOT a shell parser:
# quoted args with embedded spaces inside a global opt, `eval`, and base64
# payloads remain holes (the `git -C` family is the realistic one).
let dequoteFlag = re"""['"](-{1,2}[^'"\s]+)['"]"""
let gitGlobalOpts =
  re"""^git\s+((?:-[Cc]\s+\S+|--(?:git-dir|work-tree|namespace|super-prefix)(?:=\S+|\s+\S+)|--exec-path=\S+|-p|-P|--paginate|--no-pager|--bare|--no-replace-objects|--literal-pathspecs|--icase-pathspecs|--no-optional-locks)\s+)+"""

# Same chaining-split pattern as secret-guard.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

# Tier 1: verb alone is enough to ask.
let tier1Verbs = re"""^git\s+(rebase|filter-branch|filter-repo)(\s|$)"""

# Carry-over from the original commit/push-only version, since split three ways
# because the three now land in different tiers.
#
# `--amend` rewrites the last commit rather than recording a new one, so it is
# lifted out of the routine-commit tier into catastrophic (never auto-allow) —
# it is the local half of the amend-then-force-push rewrite, and force-push is
# already catastrophic. Must be tested BEFORE commitPlain, which it also matches.
let commitAmend = re"""^git\s+commit\s+(.*\s)?--amend(\s|$)"""

# A plain `git commit` records reflog-recoverable local state. It stays detected
# — the adjudicated reason is worth having in the transcript — but the enum is
# narrowed to {allow,ask} so a deny is structurally impossible. See isSoftCommit.
let commitPlain = re"""^git\s+commit(\s|$)"""

let pushAny = re"""^git\s+push(\s|$)"""

# Universal --force guard — any git subcommand with a standalone `--force`
# flag (filter-repo, filter-branch, branch, tag, checkout, clean, …) asks.
# Word boundary on the right is `\s|$|=` so `--force-with-lease` does NOT
# match here (the safer form is still gated by the push-specific pattern).
let forceFlag = re"""^git\s+.*\s--force(\s|$|=)"""

# Named destructive patterns, reused by both tier-2 detection (below) and the
# catastrophic "never auto-allow" check (further below).
let
  # reset --hard (discards worktree/index)
  resetHard = re"""^git\s+reset\s+(.*\s)?--hard\b"""
  # force push — `(.*\s)?` (not `.*(\s)`) so a FIRST-position flag is caught;
  # the old `.*(\s)` form missed `git push -f origin` (flag before the remote).
  pushForceFlags =
    re"""^git\s+push\s+(.*\s)?(--force|--force-with-lease(=\S+)?|-f)(\s|$)"""
  # +refspec push shorthand (e.g., `git push origin +master`)
  pushPlusRefspec = re"""^git\s+push\s+.*\s\+\S+"""
  # checkout discarding worktree changes; checkout -f (forceFlag misses bare -f)
  checkoutDiscard = re"""^git\s+checkout\s+(--|\.)(\s|$)"""
  checkoutForce = re"""^git\s+checkout\s+(.*\s)?-f(\s|$)"""
  # restore — destructive unless --staged-only; ask/never-allow on all forms
  restoreAny = re"""^git\s+restore(\s|$)"""
  # clean — destructive except the -n/--dry-run no-op
  cleanAny = re"""^git\s+clean(\s|$)"""
  cleanDryRun = re"""^git\s+clean\s+(.*\s)?(-n|--dry-run)(\s|$)"""
  # reflog destruction + immediate gc prune (both destroy the recovery path)
  reflogDestroy = re"""^git\s+reflog\s+(expire|delete|clear)(\s|$)"""
  gcPrune = re"""^git\s+gc\s+.*--prune(=|\s+)(now|[0-9])"""
  # force-clobber refs / switch-discard
  branchForce = re"""^git\s+branch\s+(.*\s)?(-f|-M|--force)(\s|$)"""
  tagForce = re"""^git\s+tag\s+(.*\s)?(-f|--force)(\s|$)"""
  switchDiscard = re"""^git\s+switch\s+(.*\s)?(--discard-changes|-f|--force)(\s|$)"""
  # stash drop|clear are catastrophic; `pop` is detected (tier2) but allowable
  stashDropClear = re"""^git\s+stash\s+(drop|clear)(\s|$)"""
  # catastrophic-only remote-destructive push forms (plain push detection is
  # already covered by commitPush; plain fast-forward push stays auto-allowable)
  pushDelete = re"""^git\s+push\s+(.*\s)?(--delete|-d)(\s|$)"""
  pushColonRef = re"""^git\s+push\s+.*\s:\S+"""
  pushMirror = re"""^git\s+push\s+.*--mirror"""

# Tier 2: destructive flag/arg combinations on otherwise-safe verbs.
# False-positive cost = one extra confirm; we err on the side of asking.
let tier2Patterns = [
  resetHard,

  # stash operations — `pop` kept here for detection (allowable, NOT catastrophic)
  re"""^git\s+stash\s+(drop|clear|pop)(\s|$)""",
  re"""^git\s+stash\s+push\s+(.*\s)?(-u|--include-untracked|-a|--all)(\s|$)""",
  re"""^git\s+stash\s+save\s+(.*\s)?(-u|--include-untracked|-a|--all)(\s|$)""",

  # branch deletion (short and long forms) + force-clobber
  re"""^git\s+branch\s+(.*\s)?(-[dD]|--delete)(\s|$)""",
  branchForce,
  checkoutDiscard,
  checkoutForce,
  restoreAny,
  cleanAny,
  switchDiscard,

  # rm — removes tracked files from the worktree and index; `--cached` only
  # unstages, but per house style we ask on every form rather than carve out
  # the safe sub-forms.
  re"""^git\s+rm(\s|$)""",
  pushForceFlags,
  pushPlusRefspec,
  reflogDestroy,
  gcPrune,

  # low-level ref deletion / scripted deletes via stdin
  re"""^git\s+update-ref\s+(.*\s)?-d\b""",
  re"""^git\s+update-ref\s+(.*\s)?--stdin(\s|$)""",

  # tag deletion (short and long) + force-clobber
  re"""^git\s+tag\s+(.*\s)?(-d|--delete)(\s|$)""",
  tagForce,

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

# Catastrophic ("never auto-allow") set — irreversible (not reflog/fsck-
# recoverable) or destructive-remote. On gate-ON these are forced to {ask,deny}
# regardless of conversation / config, so injection can only make them stricter.
# (cleanAny is checked separately in isCatastrophic to exclude the dry-run no-op.)
let catastrophicPatterns = [
  tier1Verbs, commitAmend, forceFlag, pushForceFlags, pushPlusRefspec, pushDelete,
  pushColonRef, pushMirror, resetHard, checkoutDiscard, checkoutForce, restoreAny,
  switchDiscard, stashDropClear, reflogDestroy, gcPrune, branchForce, tagForce,
]

proc stripEnvPrefix(segment: string): string =
  ## Remove leading `KEY=value` env-var assignments so e.g.
  ## `GIT_SEQUENCE_EDITOR=/tmp/x git rebase -i HEAD~3` parses leading-token
  ## as `git`. Idempotent: returns segment unchanged if no env-prefix.
  segment.replace(envAssignPrefix, "")

proc normalizeSegment(segment: string): string =
  ## Canonicalize a segment for pattern matching: strip the env-prefix, unwrap
  ## quoted flags, then re-anchor `git <global-opts> <verb>` → `git <verb>`.
  ## Safe-ward — a quoted arg that merely looks like a flag may be unwrapped,
  ## yielding at worst a false ask, never a missed catastrophic.
  result = stripEnvPrefix(segment.strip()).replacef(dequoteFlag, "$1")
  if result.startsWith("git") and result.contains(gitGlobalOpts):
    result = "git " & result.replace(gitGlobalOpts, "")

proc segmentRisk(segment: string): string =
  ## Returns a short risk label if this segment is risky, "" otherwise.
  let s = normalizeSegment(segment)
  if s.contains(tier1Verbs) or s.contains(commitAmend):
    return "rewrites history"
  if s.contains(commitPlain) or s.contains(pushAny):
    return "publishes / records state"
  if s.contains(forceFlag):
    return "--force flag"
  for pat in tier2Patterns:
    if s.contains(pat):
      return "destructive flag/arg"
  return ""

proc isCatastrophic(segment: string): bool =
  ## Irreversible (not reflog/fsck-recoverable) or destructive-remote → never
  ## auto-allow. cleanAny is special-cased to exclude the -n/--dry-run no-op.
  let s = normalizeSegment(segment)
  if s.contains(cleanAny) and not s.contains(cleanDryRun):
    return true
  for pat in catastrophicPatterns:
    if s.contains(pat):
      return true
  false

proc decisionsExcludingAllow(base: seq[string]): seq[string] =
  ## `base` with "allow" removed; an empty or allow-only `base` → {ask,deny}.
  ## Forces a catastrophic command to a no-auto-allow floor without depending on
  ## the per-hook GIT_CONFIRM_GUARD_DECISIONS configuration.
  if base.len == 0:
    return @["ask", "deny"]
  for d in base:
    if d != "allow":
      result.add d
  if result.len == 0:
    result = @["ask", "deny"]

proc isSoftCommit(segment: string): bool =
  ## True for a plain `git commit` — no `--amend`, nothing else risky in the
  ## segment. These record reflog-recoverable local state and are the single
  ## most common flagged command; a hard block on one is never the right answer.
  let s = normalizeSegment(segment)
  s.contains(commitPlain) and not s.contains(commitAmend) and not isCatastrophic(s)

proc decisionsExcludingDeny(base: seq[string]): seq[string] =
  ## `base` with "deny" removed; an empty or deny-only `base` → {allow,ask}.
  ## Mirror of decisionsExcludingAllow: gives a plain commit a no-hard-block
  ## floor, so the worst the classifier can do to a routine commit is ask.
  if base.len == 0:
    return @["allow", "ask"]
  for d in base:
    if d != "deny":
      result.add d
  if result.len == 0:
    result = @["allow", "ask"]

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return
  if not cmd.contains(mentionsGit):
    return # fast path — no git verb anywhere

  var matched: seq[string] = @[]
  var catastrophic = false
  # Only softened when EVERY flagged segment is a plain commit — one risky
  # sibling in a `git commit … && git push --force` chain revokes the floor.
  var softCommitOnly = true
  for segment in cmd.split(shellChainingSplit):
    let s = segment.strip()
    if s.len == 0:
      continue
    let risk = segmentRisk(s)
    if risk.len > 0:
      let stripped = stripEnvPrefix(s)
      matched.add("`" & stripped & "` (" & risk & ")")
      if isCatastrophic(s):
        catastrophic = true
      if not isSoftCommit(s):
        softCommitOnly = false

  # Union (AST ∪ regex): tree-sitter-bash catches nested/quoted forms the regex
  # split misses — e.g. `echo $(git push --force)`, where the split on `$(`
  # leaves `git push --force)` and `--force)` fails the right-boundary. Strictly
  # additive: only ADDS a catch or escalates `catastrophic` (never removes one).
  # On AstGrepError the regex result above stands — exactly the pre-AST behavior.
  try:
    let astFired = firedRuleIds(combined("git-confirm"), cmd)
    if astFired.len > 0:
      if matched.len == 0: # regex missed it (nested/exotic form) — surface it
        let labels = astFired.mapIt(ruleMeta.getOrDefault(it).label).deduplicate
        matched.add("`" & cmd.strip() & "` (" & labels.join(", ") & ", via ast)")
      if astFired.anyIt(ruleMeta.getOrDefault(it).catastrophic):
        catastrophic = true
      # An AST firing means a nested/quoted form the regex tier did not model.
      # Never soften on one: the softening floor is only for shapes we parsed.
      softCommitOnly = false
  except AstGrepError:
    discard

  if matched.len == 0:
    return

  let label = if matched.len == 1: "segment" else: "segments"
  let askReason =
    "git-confirm-guard: confirm before running git " & label & ": " & matched.join(", ") &
    ". These rewrite history, destroy local state, or publish to remote " &
    "— every one requires explicit approval."

  if not gateOn():
    emit("ask", askReason)
    return

  # Two opposing floors, catastrophic first so it wins any overlap:
  #   catastrophic  → drop `allow`, so conversation, config, or a successful
  #                   injection can only ever make the decision stricter.
  #   plain commit  → drop `deny`, so the worst a routine commit can cost is
  #                   one confirm. Revoked by any risky sibling segment or any
  #                   AST-only match (see softCommitOnly).
  let decisions =
    if catastrophic:
      decisionsExcludingAllow(allowedDecisions())
    elif softCommitOnly:
      decisionsExcludingDeny(allowedDecisions())
    else:
      allowedDecisions()
  let decision = adjudicate(
    cmd,
    "git-confirm-classify",
    provider = classifierProvider(),
    model = classifierModel(),
    transcriptPath = payload{"transcript_path"}.getStr(""),
    contextTurns = ContextTurns,
    allowedDecisions = decisions,
    timeoutSecs = TimeoutSecs,
  )
  if decision.isNone:
    emit("ask", askReason) # classifier unavailable → current static behavior
    return
  let d = decision.get
  emit(d.permissionDecision, d.reason, d.additionalContext)

when isMainModule:
  main()
