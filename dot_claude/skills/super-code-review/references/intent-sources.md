# Intent Sources

The `shortcut-intent-reviewer` needs to know what the diff was *supposed* to do, so it can flag drift. This file describes how to gather that context, in parallel, from each source.

`--intent` accepts a comma-separated allowlist: `pr`, `issue`, `bd`, `plan`, `all`, `none`. Default is `auto` which means "try each, use whatever's available."

## PR body / commit message body

**When:** `pr` in the allowlist AND source mode is `pr`, OR `pr` in the allowlist AND source mode is `range`/`working` (then fall back to commit bodies).

```bash
# PR mode
gh pr view "$PR" --json title,body -q '{title: .title, body: .body}'

# Range / working mode — last few commit bodies as fallback
git log --format='%H%n%s%n%b%n---' "$RANGE"     # for range mode
git log -5 --format='%H%n%s%n%b%n---'           # for working-tree mode (last 5)
```

Extract:
- Stated goal / acceptance criteria
- Out-of-scope notes ("not changing X in this PR")
- References to other work (`#123`, `bd:42`, `Fixes #X`, plan file paths)

## Linked GitHub issues

**When:** `issue` in the allowlist AND the PR body or commit bodies reference `#NNN`, `Fixes #NNN`, `Closes #NNN`, or `Refs #NNN`.

```bash
# Extract issue numbers from PR/commit bodies
grep -oE '(Fixes|Closes|Refs|Re:|#)\s*#?[0-9]+' <<<"$PR_BODY_OR_COMMITS" | grep -oE '[0-9]+' | sort -u

# Fetch each
for ISSUE in $ISSUE_NUMBERS; do
  gh issue view "$ISSUE" --json title,body,labels,state -q '{number: '$ISSUE', title: .title, body: .body, state: .state, labels: [.labels[].name]}'
done
```

Filter out:
- Closed issues that are clearly unrelated (e.g., the PR body mentions `#100` in passing but #100 is a 2-year-old wontfix)
- Issues whose body doesn't relate to any file changed in this diff

## Beads (`bd`) issues

**When:** `bd` in the allowlist AND there's a beads ID referenced. Common patterns:

- Branch name like `feat/bd-42-add-auth`
- Commit body or PR body containing `bd:42`, `bd-42`, or `beads #42`

```bash
# Get branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Try to extract beads ID from branch + commit bodies + PR body
BD_IDS=$(echo "$BRANCH $COMMIT_BODIES $PR_BODY" | grep -oE '\bbd[:-][0-9]+\b' | grep -oE '[0-9]+' | sort -u)

# Fetch each
for ID in $BD_IDS; do
  bd show "$ID" 2>/dev/null   # bd CLI must be on PATH; skip silently if absent
done
```

If `bd` is not installed on PATH, skip this source silently — don't error.

## Plan files

**When:** `plan` in the allowlist AND there's a referenced plan file, OR a `.claude/plans/*.md` file was modified recently in the branch.

Detection paths:

```bash
# 1. Plan files referenced from PR body or commit bodies
grep -oE '(plans?/[A-Za-z0-9_./-]+\.md|PLAN\.md|\.claude/plans/[A-Za-z0-9_./-]+\.md)' <<<"$PR_BODY_OR_COMMITS" | sort -u

# 2. Plan files modified in the diff (the author updated/created a plan as part of this change)
git diff --name-only "$RANGE" | grep -E '(^|/)(PLAN\.md|plans/.*\.md|\.claude/plans/.*\.md)$'

# 3. Plan files created during plan mode for this branch
ls -t .claude/plans/*.md 2>/dev/null | head -3   # MOST recent 3, sorted by mtime
```

Read each candidate plan file in full — they're usually small and full of acceptance criteria.

**Note:** The third command uses `head` as part of a `sort | head` top-N idiom, which is allowed under the truncation rule. The full content of each *file* is read separately via `Read`.

## Aggregation

Merge all intent sources into a single intent context string passed to the `shortcut-intent-reviewer`:

```
INTENT CONTEXT
==============

[PR title]
<title>

[PR body / latest commit body]
<full text>

[Linked issue #123]
title: <title>
body: <body>

[Beads issue 42]
<bd show output>

[Plan file: .claude/plans/auth-overhaul.md]
<full file contents>

==============
```

If nothing was gathered, pass `INTENT CONTEXT: (empty — drift detection skipped)`. The shortcut-intent-reviewer will then skip the drift pass and run shortcut detection only.

## Privacy

Intent context can contain sensitive details (customer names, internal URLs, credentials referenced in issues). The skill operates locally — nothing leaves the machine except through `gh` (which goes to GitHub anyway). But: when invoking `codex:codex-rescue`, intent context goes through the Codex CLI/API. If the user has indicated this is a private/sensitive repo, **omit** the intent context from the Codex spawn prompt and rely on the diff alone for the second opinion.

(There's no flag for this yet — surface as a follow-up if it matters to the user.)
