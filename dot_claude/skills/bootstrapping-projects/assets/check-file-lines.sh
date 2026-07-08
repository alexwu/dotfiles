#!/usr/bin/env sh
# The headline anti-sprawl gate: fail if any passed file exceeds the line cap.
# Keeps AI-generated source from ballooning into unmaintainable blobs — the one
# rule no mainstream linter enforces at the FILE level (clippy/SwiftLint/pylint
# cap functions or have it scattered; Rust + Nim have nothing). Language-agnostic,
# zero dependencies, identical behavior in CI.
#
# Copy this into a new project as scripts/check-file-lines.sh (chmod +x) and wire
# it as a prek local hook. Tune the cap per project with FILE_LINE_MAX.
set -eu

max="${FILE_LINE_MAX:-400}"
status=0
for f in "$@"; do
  [ -f "$f" ] || continue
  lines=$(wc -l <"$f" | tr -d ' ')
  if [ "$lines" -gt "$max" ]; then
    printf 'ERROR: %s has %d lines (max %d) — split it.\n' "$f" "$lines" "$max" >&2
    status=1
  fi
done
exit "$status"
