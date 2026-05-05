## check-plan: post-Phase-4.5 sanity gate for plan-mode-plans.
##
## Verifies an implementation plan (single Markdown file or agent-teams
## directory) contains the required template sections and shows evidence
## that the Phase 4.5 audit ran or was explicitly skipped.
##
## Exits 0 on pass, 1 on missing required sections, 2 on bad input path.

import std/[os, strutils]

import cligen

const
  RequiredSections = [
    "## Goal", "## Context", "## Decisions", "## Files Affected", "## Approach",
    "## Risks", "## Verification",
  ]
  AuditEvidence = [
    "Plan audits skipped", "Codex audit skipped", "Audit Info notes",
    "Escalation audit", "User-Confirmed Decisions", "Phase 4.5",
  ]

func sectionPresent(content: string, section: string): bool =
  ## Mimics the bash `rg -q "^<section>\b"` check: the section must appear
  ## at the start of a line, followed by a non-word character (space, colon,
  ## punctuation, or end-of-line) so "## Goalpost" doesn't satisfy "## Goal".
  for line in content.splitLines:
    if line == section:
      return true
    if line.startsWith(section):
      let next = line[section.len]
      if not next.isAlphaNumeric and next != '_':
        return true

func hasAuditEvidence(content: string): bool =
  for token in AuditEvidence:
    if content.contains(token):
      return true

proc collectTargets(plan: string): seq[string] =
  ## A directory plan is index.md plus any top-level numbered section files;
  ## a file plan is just itself.
  if dirExists(plan):
    let indexPath = plan / "index.md"
    if fileExists(indexPath):
      result.add(indexPath)
    for kind, path in walkDir(plan):
      if kind != pcFile:
        continue
      let name = extractFilename(path)
      if name == "index.md":
        continue
      if name.endsWith(".md") and name.len > 0 and name[0].isDigit:
        result.add(path)
  else:
    result.add(plan)

proc checkPlan(plan: string): int =
  ## Sanity-check a plan-mode-plans plan file or directory.
  if not fileExists(plan) and not dirExists(plan):
    stderr.writeLine "FAIL: plan path does not exist: " & plan
    return 2

  let targets = collectTargets(plan)
  var failed = false
  var warned = false

  for f in targets:
    if not fileExists(f):
      stderr.writeLine "FAIL: " & f & " does not exist"
      failed = true
      continue

    let content = readFile(f)

    # Required sections only apply to single-session plans (one target) or
    # the agent-teams index.md — section files have their own shape.
    let baseName = extractFilename(f)
    if baseName == "index.md" or targets.len == 1:
      for section in RequiredSections:
        if not sectionPresent(content, section):
          stderr.writeLine "FAIL [" & f & "]: required section '" & section &
            "' not found"
          failed = true

    if not hasAuditEvidence(content):
      stderr.writeLine "WARN [" & f & "]: no evidence Phase 4.5 audits were " &
        "run or skipped (expected one of: 'Plan audits skipped', " &
        "'Codex audit skipped', 'Audit Info notes', 'Escalation audit', " &
        "'User-Confirmed Decisions', or 'Phase 4.5' reference)"
      warned = true

  if failed:
    stderr.writeLine "check-plan: FAIL (missing required sections)"
    return 1
  if warned:
    stderr.writeLine "check-plan: PASS with warnings"
  else:
    stderr.writeLine "check-plan: PASS"
  return 0

proc main(plan: seq[string]): int =
  ## Sanity-check a plan-mode-plans plan file or directory.
  ##
  ## plan: path to a plan .md file (single-session) OR a directory
  ## containing index.md and numbered section files (agent-teams).
  if plan.len != 1:
    stderr.writeLine "Usage: check-plan <plan-file-or-directory>"
    return 2
  return checkPlan(plan[0])

when isMainModule:
  dispatch(
    main,
    cmdName = "check-plan",
    positional = "plan",
    help = {"plan": "Plan file or directory to check"},
  )
