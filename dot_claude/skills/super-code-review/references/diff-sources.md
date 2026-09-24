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
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
DEFAULT=${DEFAULT#origin/}
# No origin/HEAD (no remote, or never set): fall back to main, else master.
: "${DEFAULT:=$(git rev-parse --verify -q main >/dev/null && echo main || echo master)}"
git rev-list --count "$DEFAULT..HEAD"
```

If non-zero, use **range mode** with `$DEFAULT...HEAD`. Keep the fallback: with `DEFAULT` empty, `git rev-list --count "..HEAD"` prints `0` and exits 0, which silently skips range mode.

```bash
# Step 3 — working-tree candidate
git status --porcelain
```

If non-empty, use **working-tree mode**. `git status` catches staged-only and untracked changes; `git diff --stat` misses both.

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

Reviews uncommitted changes: staged, unstaged, and untracked.

```bash
# Staged + unstaged (everything tracked, since HEAD)
git diff HEAD

# Or split if needed
git diff --cached    # staged only
git diff             # unstaged only

# Untracked files — git diff HEAD never shows these. Render each as a new-file diff.
# --no-index exits 1 when the files differ, which is always here; that's not an error.
# -n1, not -I{}: macOS xargs -I truncates substituted paths at 255 bytes.
git ls-files --others --exclude-standard -z \
  | xargs -0 -n1 git diff --no-index -- /dev/null

# Changed file list (tracked + untracked)
git diff --name-only HEAD
git ls-files --others --exclude-standard
```

Concatenate the tracked and untracked diffs into one unified diff. Don't `git add -N` to make untracked files show up in `git diff`; that writes to the index, and the pipeline is read-only.

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

Write it to a file and pass the path; reviewers `Read` it. Use the Write tool to create `super-code-review-diff.patch` in the scratchpad directory named in your system prompt. If the host names none, create it under `mktemp -d`.

Write the **normalized** diff, the same text you'd otherwise inline. Regenerating it with a fresh `git diff` loses whatever the mode added; in working-tree mode that's every untracked file.

Delete the file at the end of the run.

## Skip-paths

Before fan-out, filter the changed file list to skip:

- Generated files: `Cargo.lock`, `package-lock.json`, `pnpm-lock.yaml`, `*.pbxproj` (only line-count changes), `Package.resolved`
- Vendored: `vendor/`, `Pods/`, `node_modules/`, `Carthage/`
- Build artifacts: `.build/`, `build/`, `dist/`, `target/`, `.next/`
- Binary fixtures: anything `git diff` reports as "Binary files differ"

Keep them in the diff-summary count but don't ask reviewers to audit them.
