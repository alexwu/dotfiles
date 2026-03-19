#!/usr/bin/env bash
# Validates git add commands to block 'git add -A' and similar patterns
# while allowing specific file additions.

# Read JSON from stdin
input=$(cat)

# Extract command using jaq (Rust jq clone)
command=$(echo "$input" | jaq -r '.tool_input.command // empty')

# Only validate git add commands
if [[ ! "$command" =~ ^git[[:space:]]+add ]]; then
  exit 0  # Allow non-git commands
fi

# Block patterns: -A, --all, ., -u, --update
if [[ "$command" =~ git[[:space:]]+add[[:space:]]+(-A|--all|\.|--update|-u)([[:space:]]|$) ]]; then
  echo "❌ Blocked: 'git add -A' / '--all' / '.' is not allowed." >&2
  echo "Instead, use: git add file1.txt file2.txt" >&2
  echo "Or: git add directory/" >&2
  echo "Or: git add -p (for interactive staging)" >&2
  exit 2  # Block command
fi

# Allow specific files/directories
exit 0
