## Tests for check_plan's Scope Ledger validation. Run with:
##   nim c -r --hints:off scripts/claude/test_check_plan.nim

import std/[strutils, unittest]

import check_plan

proc plan(rows: varargs[string]): string =
  ## A minimal plan whose Scope Ledger holds `rows` (each "Item | Home | Status").
  var table = "| # | Item | Source | Home | Status |\n|---|---|---|---|---|\n"
  for i, row in rows:
    let parts = row.split(" | ")
    table.add "| " & $(i + 1) & " | " & parts[0] & " | user: \"x\" | " & parts[1] & " | " &
      parts[2] & " |\n"
  "# Plan\n\n## Goal\n\nShip it.\n\n## Scope Ledger\n\n" & table &
    "\n## Risks\n\n- none\n"

suite "ledger rows":
  test "parses rows by header name":
    let (found, rows) = ledgerRows(plan("Bucket | Steps 1-3 | planned"))
    check found
    check rows.len == 1
    check rows[0].item == "Bucket"
    check rows[0].home == "Steps 1-3"
    check rows[0].status == "planned"

  test "ignores a ledger shown inside a code fence":
    let text =
      "# Plan\n\n```markdown\n## Scope Ledger\n| # | Item | Source | Home | Status |\n```\n"
    check not ledgerRows(text)[0]

  test "strips backticks around the Home":
    check ledgerRows(plan("A | `bd tools-8k2` | filed"))[1][0].home == "bd tools-8k2"

suite "allowed homes":
  test "every allowed form passes":
    for home in [
      "Phase 2", "Steps 4-5", "Step 7", "Cycle 3", "Section 2", "bd tools-8k2",
      "bd eo-workspace-5kw.7", "#123", "cleverific/eo#3982", "handoff .handoff/x.md",
      "to file: bead", "to file: gh issue", "to file: handoff", "to file: next plan",
      "dropped — \"single-node is fine\"", "dropped -- \"nah\"",
      "dropped — “not now”",
    ]:
      check ledgerProblems(plan("A | " & home & " | planned"), filed = false).len == 0

  test "bare deferrals fail":
    for home in [
      "later", "follow-up", "TBD", "v2", "next PR", "", "dropped",
      "dropped — for simplicity",
    ]:
      check ledgerProblems(plan("A | " & home & " | planned"), filed = false).len == 1

  test "unknown status fails":
    check ledgerProblems(plan("A | Phase 1 | someday"), filed = false).len == 1

suite "ledger presence":
  test "a missing section fails":
    check ledgerProblems("# Plan\n\n## Goal\n\nx\n", filed = false) ==
      @["no '## Scope Ledger' section"]

  test "an empty table fails":
    let text =
      "# Plan\n\n## Scope Ledger\n\n| # | Item | Source | Home | Status |\n|---|---|---|---|---|\n"
    check ledgerProblems(text, filed = false) == @["'## Scope Ledger' has no rows"]

suite "--filed":
  test "provisional rows pass before Phase 6":
    check ledgerProblems(plan("A | to file: bead | provisional"), filed = false).len == 0

  test "provisional rows fail after Phase 6":
    let problems = ledgerProblems(plan("A | to file: bead | provisional"), filed = true)
    check problems.len == 1
    check "still unfiled" in problems[0]

  test "filed rows pass after Phase 6":
    check ledgerProblems(plan("A | bd tools-8k2 | filed"), filed = true).len == 0
