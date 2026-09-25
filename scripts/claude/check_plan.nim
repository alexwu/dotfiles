## check-plan: post-Phase-4.5 gate for plan-mode-plans.
##
## Lints an implementation plan (single Markdown file or agent-teams
## directory) with rumdl and checks for evidence that the Phase 4.5 audits ran
## or were explicitly skipped. Everything is linted with
## ~/.config/rumdl/plan.rumdl.toml (house style plus the required template
## sections, in order); numbered agent-teams section files skip the
## required-sections rule, since only the plan file or index.md carries them.
##
## Exits 0 on pass, 1 on lint findings or missing audit evidence, 2 on a bad
## path, a plan directory with no index.md, a missing rumdl binary or config,
## or a rumdl error.

import std/[algorithm, os, osproc, sequtils, strutils]

import cligen

const
  AuditEvidence = "Phase 4.5 audits:"
    ## SKILL.md's Phase 4.5 step 9 has the planner record every outcome,
    ## including a skip, on one line with this prefix. The plan template's
    ## placeholder deliberately doesn't contain it, so a template copied
    ## verbatim can't pass.
  UnfixableRules = "MD063,MD040"
    ## MD063's fix recases bare identifiers in headings and MD040's labels an
    ## unknown fence `text`. Both need the author's judgment, so `--fix`
    ## leaves them as findings.

type Target = object
  path: string
  primary: bool ## the single-session plan or the agent-teams index.md

proc collectTargets(plan: string): seq[Target] =
  ## A directory plan is index.md plus any top-level numbered section files;
  ## a file plan is just itself.
  if not dirExists(plan):
    return @[Target(path: plan, primary: true)]
  let indexPath = plan / "index.md"
  if fileExists(indexPath):
    result.add Target(path: indexPath, primary: true)
  var sections: seq[string]
  for kind, path in walkDir(plan):
    let name = extractFilename(path)
    if kind == pcFile and name.endsWith(".md") and name[0].isDigit:
      sections.add path
  sections.sort()
  for path in sections:
    result.add Target(path: path, primary: false)

proc runRumdl(rumdl: string, args: seq[string]): int =
  let process = startProcess(rumdl, args = args, options = {poParentStreams})
  result = process.waitForExit()
  process.close()

proc lint(
    rumdl, config: string, files: seq[string], fix: bool, extra: seq[string] = @[]
): int =
  ## Returns rumdl's exit code: 0 clean, 1 findings, 2 error.
  if files.len == 0:
    return 0
  let common = @["--config", config, "--deny-config-warnings"] & extra
  if fix:
    let fmtArgs = @["fmt"] & common & @["--unfixable", UnfixableRules] & files
    if runRumdl(rumdl, fmtArgs) != 0:
      return 2
  runRumdl(rumdl, @["check"] & common & files)

proc checkPlan(plan: string, fix: bool): int =
  if not fileExists(plan) and not dirExists(plan):
    stderr.writeLine "FAIL: plan path does not exist: " & plan
    return 2

  let targets = collectTargets(plan)
  if not targets.anyIt(it.primary):
    stderr.writeLine "FAIL: plan directory has no index.md: " & plan
    return 2

  # A mise shim is a symlink to the mise binary, which dispatches on the name
  # it was invoked as; following the link would exec mise itself.
  let rumdl = findExe("rumdl", followSymlinks = false)
  if rumdl.len == 0:
    stderr.writeLine "FAIL: rumdl not found on PATH (brew install rumdl)"
    return 2

  let config = getConfigDir() / "rumdl" / "plan.rumdl.toml"
  if not fileExists(config):
    stderr.writeLine "FAIL: rumdl config not found: " & config & " (run chezmoi apply)"
    return 2

  let
    primaries = targets.filterIt(it.primary).mapIt(it.path)
    sections = targets.filterIt(not it.primary).mapIt(it.path)
    lintCode = max(
      lint(rumdl, config, primaries, fix),
      lint(rumdl, config, sections, fix, extra = @["--disable", "MD043"]),
    )
  if lintCode >= 2:
    stderr.writeLine "check-plan: FAIL (rumdl error)"
    return 2

  # The outcome line lives in Risks, so only the single-session plan or
  # index.md must carry it.
  var missingEvidence = false
  for path in primaries:
    if not readFile(path).contains(AuditEvidence):
      stderr.writeLine "FAIL [" & path & "]: no '" & AuditEvidence &
        "' line in Risks recording the audit outcome (see Phase 4.5 step 9)"
      missingEvidence = true

  if lintCode == 1 or missingEvidence:
    stderr.writeLine "check-plan: FAIL"
    return 1
  stderr.writeLine "check-plan: PASS"

proc main(fix = false, plan: seq[string]): int =
  ## Lint a plan-mode-plans plan file or directory with rumdl and check it
  ## for Phase 4.5 audit evidence.
  ##
  ## plan: path to a plan .md file (single-session) OR a directory
  ## containing index.md and numbered section files (agent-teams).
  if plan.len != 1:
    stderr.writeLine "Usage: check-plan [--fix] <plan-file-or-directory>"
    return 2
  checkPlan(plan[0], fix)

when isMainModule:
  dispatch(
    main,
    cmdName = "check-plan",
    positional = "plan",
    help = {
      "fix":
        "apply rumdl's auto-fixes before checking (MD063 and MD040 " &
        "stay report-only)",
      "plan": "Plan file or directory to check",
    },
  )
