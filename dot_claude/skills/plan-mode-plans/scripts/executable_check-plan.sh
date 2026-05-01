#!/usr/bin/env bash
# check-plan.sh: post-Phase-4.5 sanity gate for plan-mode-plans
# Usage: check-plan.sh <plan-path>
#   <plan-path>: file (single-session) OR directory (agent-teams)
#
# Verifies:
#   - All required template sections are present
#   - Audit was either run (Phase 4.5 reference, Audit Info notes) or
#     explicitly skipped (Codex audit skipped per user request)
# Exit 0 on pass, non-zero on missing required sections.

set -euo pipefail

PLAN=${1:?"Usage: $0 <plan-file-or-dir>"}

if [[ ! -e "$PLAN" ]]; then
  echo "FAIL: plan path does not exist: $PLAN" >&2
  exit 2
fi

if [[ -d "$PLAN" ]]; then
  TARGETS=( "$PLAN/index.md" )
  for f in "$PLAN"/[0-9]*.md; do
    [[ -f "$f" ]] && TARGETS+=( "$f" )
  done
else
  TARGETS=( "$PLAN" )
fi

REQUIRED_SECTIONS=(
  "## Goal"
  "## Context"
  "## Decisions"
  "## Files Affected"
  "## Approach"
  "## Risks"
  "## Verification"
)

fail=0
warn=0

for f in "${TARGETS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "FAIL: $f does not exist" >&2
    fail=1
    continue
  fi

  # index.md and section files have different shapes; only check required
  # sections in index.md (single-session plan files = the only target).
  basename_f=$(basename "$f")
  if [[ "$basename_f" == "index.md" ]] || [[ "${#TARGETS[@]}" -eq 1 ]]; then
    for section in "${REQUIRED_SECTIONS[@]}"; do
      if ! rg -q "^${section}\b" "$f"; then
        echo "FAIL [$f]: required section '$section' not found" >&2
        fail=1
      fi
    done
  fi

  # Audit evidence: skip-note OR audit-info-notes OR Phase 4.5 reference
  if rg -q "Codex audit skipped" "$f" \
     || rg -q "Audit Info notes" "$f" \
     || rg -q "Phase 4\.5" "$f"; then
    : # OK, audit was run or explicitly skipped
  else
    echo "WARN [$f]: no evidence Phase 4.5 audit was run or skipped (expected one of: 'Codex audit skipped', 'Audit Info notes', or 'Phase 4.5' reference)" >&2
    warn=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "check-plan: FAIL (missing required sections)" >&2
  exit 1
fi

if [[ $warn -ne 0 ]]; then
  echo "check-plan: PASS with warnings" >&2
else
  echo "check-plan: PASS" >&2
fi
exit 0
