## Shared helper: run an ast-grep YAML rule (or multi-doc rule set) against a
## single Bash command string and report what matched.
##
## The PreToolUse guards receive one command at a time on stdin (inside the
## Claude Code JSON envelope). ast-grep is a file/stdin scanner, so we feed the
## command on the child's stdin via `--stdin` and read structured `--json` back.
## `scan` exits 0 whether or not it matched, so a match is detected by the JSON
## result array being non-empty — NOT by exit code. ANY infra failure (launch /
## non-zero exit / unparseable JSON) raises `AstGrepError`, so callers can
## distinguish "no match" from "classifier broken" and fall back / fail-closed
## where that matters. stderr is merged into stdout (`poStdErrToStdOut`) so a
## verbose error stream can't deadlock on a full pipe buffer.

import std/[json, osproc, streams, strutils]

const AstGrepBin = "ast-grep"

type AstGrepError* = object of CatchableError

proc runAstGrep(ruleYaml, cmd: string): JsonNode =
  ## Spawn ast-grep over `ruleYaml` (one or more `---`-separated rule docs)
  ## against `cmd` on stdin and return the parsed `--json` result array. Raises
  ## `AstGrepError` on any infra failure so callers fail-closed / fall back.
  var p: Process
  try:
    p = startProcess(
      AstGrepBin,
      args = ["scan", "--inline-rules", ruleYaml, "--stdin", "--json"],
      options = {poUsePath, poStdErrToStdOut},
    )
  except OSError as e:
    raise newException(AstGrepError, "could not launch ast-grep: " & e.msg)

  p.inputStream.write(cmd)
  p.inputStream.close()
  let raw = p.outputStream.readAll()
  let code = p.waitForExit()
  p.close()

  if code != 0:
    raise newException(
      AstGrepError, "ast-grep exited " & $code & " (output: " & raw.strip() & ")"
    )
  try:
    parseJson(raw.strip())
  except CatchableError as e:
    raise newException(AstGrepError, "unparseable ast-grep JSON: " & e.msg)

proc astFires*(ruleYaml, cmd: string): bool =
  ## True when `ruleYaml` (an ast-grep rule with `language: bash`) matches
  ## `cmd`. Raises `AstGrepError` if ast-grep cannot be run or errors — a
  ## broken rule must never silently read as "no match".
  let j = runAstGrep(ruleYaml, cmd)
  j.kind == JArray and j.len > 0

proc anyFires*(rules: openArray[string], cmd: string): bool =
  ## True when ANY rule in `rules` matches `cmd`. This is how a guard built
  ## from several risk patterns decides whether to fire.
  for r in rules:
    if astFires(r, cmd):
      return true
  false

proc firedRuleIds*(combinedYaml, cmd: string): seq[string] =
  ## Deduped `ruleId`s that matched, from ONE ast-grep spawn over a multi-doc
  ## rule string (`combined(guard)`). Empty seq = ast-grep ran fine and nothing
  ## matched. Raises `AstGrepError` on infra failure so the caller's
  ## `except AstGrepError` fallback runs.
  let j = runAstGrep(combinedYaml, cmd)
  if j.kind == JArray:
    for m in j:
      let id = m{"ruleId"}.getStr("")
      if id.len > 0 and id notin result:
        result.add id
