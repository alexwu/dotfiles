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
rg -o --no-filename -r '$1' '(?:Fixes|Closes|Refs|Re:)?\s*#([0-9]+)' <<<"$PR_BODY_OR_COMMITS" | sort -u

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
BD_IDS=$(rg -o -r '$1' '\bbd[:-]([0-9]+)\b' <<<"$BRANCH $COMMIT_BODIES $PR_BODY" | sort -u)

# Fetch each
for ID in $BD_IDS; do
  bd show "$ID" 2>/dev/null   # bd CLI must be on PATH; skip silently if absent
done
```

If `bd` is not installed on PATH, skip this source silently — don't error.

## Plan files

**When:** `plan` in the allowlist AND there's a referenced plan file, a plan-mode plan written for this work, or a plan named by the newest handoff doc.

Claude Code writes plan-mode plans to `~/.claude/plans/` (global, random slugs), never into the repo. Codex plans go to `<repo>/.plans/`. Look in both, or plan files are silently never found.

Detection paths:

```bash
# 1. Plan files referenced from PR body or commit bodies
rg -o '(plans?/[A-Za-z0-9_./-]+\.md|PLAN\.md|\.claude/plans/[A-Za-z0-9_./-]+\.md)' <<<"$PR_BODY_OR_COMMITS" | sort -u

# 2. Plan files modified in the diff (the author updated/created a plan as part of this change)
git diff --name-only "$RANGE" | rg '(^|/)(PLAN\.md|plans/.*\.md|\.claude/plans/.*\.md)$'

# 3. Plan-mode plans, newest first: Claude Code's global dir, then Codex-style repo-local plans
eza -l --sort=modified --reverse "$HOME/.claude/plans" 2>/dev/null
eza -l --sort=modified --reverse .plans .claude/plans 2>/dev/null

# 4. The plan named by the newest handoff doc, if there is one
handoff latest 2>/dev/null | xargs -r rg -N '^- Plan:' 2>/dev/null
```

From the listings in step 3, pick the plans whose dates, titles, and Goal fit this branch; usually that's the newest one or two. `~/.claude/plans/` holds plans from every repo, so confirm a candidate's Files Affected actually point into this repo before using it. Read each candidate plan file in full. They're full of acceptance criteria.

When a plan has a `## Requested Scope` and a `## Scope Ledger`, carry both into the intent context verbatim. They're the most precise statement of intent available: the user's own words, and where every requested item was supposed to land.

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

[Plan file: ~/.claude/plans/auth-overhaul.md]
<full file contents>

[Scope Ledger from plan: ~/.claude/plans/auth-overhaul.md]
<the plan's ## Requested Scope blockquotes and ## Scope Ledger table, verbatim>

==============
```

If nothing was gathered, pass `INTENT CONTEXT: (empty — drift detection skipped)`. The shortcut-intent-reviewer will then skip the drift pass and run shortcut detection only.
