# Diff Sources

How to resolve and fetch the diff under review for each `--source` mode.

## Auto-resolution

When `--source=auto` (the default), try in order:

```bash
# Step 1 — PR mode candidate
gh pr view --json state,number,headRefName,baseRefName 2>/dev/null
```

If this returns a JSON object with `state: OPEN` (or `MERGED` if user explicitly wants a post-merge review), use **PR mode**.

```bash
# Step 2 — range mode candidate
git rev-list --count main..HEAD
```

If non-zero, use **range mode** with `main...HEAD` (substitute `master`, `develop`, or whatever the repo's default branch is — check `git symbolic-ref refs/remotes/origin/HEAD` to confirm).

```bash
# Step 3 — working-tree candidate
git diff --stat
```

If non-empty, use **working-tree mode**.

If none of the above produced anything, return early: "No changes to review."

## PR mode (`--source=pr` or `--range pr:1234`)

```bash
# Get the PR number — either from the explicit --range, or the current branch's open PR
PR=$(gh pr view --json number -q .number)   # current branch
# or: PR=1234 from --range pr:1234

# Fetch metadata
gh pr view "$PR" --json title,body,headRefOid,baseRefName,baseRefOid,headRefName,author,state,additions,deletions,changedFiles

# Get the unified diff
gh pr diff "$PR"

# Get the changed file list (cheaper than parsing the diff)
gh pr diff "$PR" --name-only
```

Capture:
- `base_sha` = `baseRefOid`
- `head_sha` = `headRefOid`
- `pr_body` = `body` (for intent context)
- `pr_title` = `title`

## Range mode (`--source=range` or `--range <git-spec>`)

Accepts any git revision range. Common forms:

```bash
RANGE="main...HEAD"            # branch vs default branch (three-dot — symmetric diff)
RANGE="HEAD~5..HEAD"           # last 5 commits
RANGE="abc123..def456"         # explicit shas

# Diff
git diff "$RANGE"

# Changed file list
git diff --name-only "$RANGE"

# Base sha — for two-dot, the left side; for three-dot, the merge-base
git merge-base $(echo "$RANGE" | awk -F'\\.\\.\\.?' '{print $1, $2}')
```

Capture:
- `base_sha` = output of `git merge-base` (for `...`) or the left side (for `..`)
- `head_sha` = `git rev-parse <right-side>`

## Working-tree mode (`--source=working` or `--range working`)

Reviews uncommitted changes. Two flavors — the skill should handle both:

```bash
# Staged + unstaged (everything since HEAD)
git diff HEAD

# Or split if needed
git diff --cached    # staged only
git diff             # unstaged only

# Changed file list
git diff --name-only HEAD
```

Capture:
- `base_sha` = `git rev-parse HEAD`
- `head_sha` = `working-tree` (sentinel — no real SHA)

## Common output shape

After source resolution, normalize to:

```json
{
  "mode": "pr|range|working",
  "base_sha": "abc123...",
  "head_sha": "def456..." | "working-tree",
  "changed_files": ["path/a.swift", "path/b.swift"],
  "diff": "<unified diff text or path to file>",
  "pr_number": 1234,         // optional, PR mode only
  "pr_title": "...",         // optional, PR mode only
  "pr_body": "..."           // optional, PR mode only
}
```

Pass this normalized object (or its contents) into Phase 1 of the pipeline.

## Diff size considerations

If the unified diff exceeds ~50 KB (~1000 lines), don't inline it into spawn prompts. Instead:

```bash
# Write to a temp file
DIFF_FILE=$(mktemp -t super-code-review-diff.XXXXXX.patch)
git diff "$RANGE" > "$DIFF_FILE"
# Pass the path to reviewer agents, they Read it
```

Clean up `$DIFF_FILE` at the end of the run.

## Skip-paths

Before fan-out, filter the changed file list to skip:

- Generated files: `Cargo.lock`, `package-lock.json`, `pnpm-lock.yaml`, `*.pbxproj` (only line-count changes), `Package.resolved`
- Vendored: `vendor/`, `Pods/`, `node_modules/`, `Carthage/`
- Build artifacts: `.build/`, `build/`, `dist/`, `target/`, `.next/`
- Binary fixtures: anything `git diff` reports as "Binary files differ"

Keep them in the diff-summary count but don't ask reviewers to audit them.
