# Passes

Re-runs on the same PR or branch are passes in a series. Every pass reviews the new work; what blocks depends on the round, and rounds have a cap. This skill enforces the cap; an implementer honors the verdict instead of counting rounds itself. Load this file in Phase 1 on every run.

## What a pass is

One run of this skill that reached Phase 5 on the same series. Runs that exit early (no diff, `ultra`, nothing new since a clean pass, "stop" at the cap question) don't count.

**The last pass** is the newest pass in the series whose effort is at or above the current run's (`low` < `medium` < `high`). A `low` look between two `high` runs doesn't count toward the `high` run's number or round. The pass number, the round, the carried findings, and `LAST_HEAD` all come from the last pass.

## Series

A series is the run of passes the rounds count over. A new series starts when:

- the last reviewed head isn't an ancestor of the new head (a rebase or force push; see "The delta" for the check per mode);
- the base branch name differs from the stored `base_ref` (a retargeted PR);
- there's no state file and no marked review;
- the delta since the last pass is itself large, by the count under "The cap" run on the delta alone; the output names the size ("1,240 lines in 12 files since pass 2: new series, full review");
- `--full` was passed.

Merging the base branch into the PR (GitHub's "Update branch", `git merge main`) keeps the series; the delta goes file-level for that pass. A whole-diff delta keeps the series too; its size says nothing about what changed.

Detached HEAD in range or working mode has no series: every run is a full pass 1 at round 1, nothing is written, and the output says so. `--full` there changes nothing.

## Rounds

A pass **blocks** when it ends with at least one `blocking: true` finding; otherwise it's **clean**. The round is the fix streak: 1 when there's no last pass or the last pass was clean, else the last pass's round plus one. A regression counts like any other blocking finding.

A clean pass approves the head it reviewed. Commits after it get an ordinary incremental pass at round 1, with no question asked. The pass number keeps counting; only the round resets. The mode (`full` on pass 1 of a series, `incremental` after) says what's reviewed, never what blocks; the round does that (SKILL.md → "Severity and blocking"). Past the cap the round is **closing**: only blockers and regressions block, and the run asks first.

## Nothing new since a clean pass

When the last pass was clean, the delta is empty (same head in PR and range mode; no file differs from `$PATCH` in working mode), and the current `--block-on` is no stricter than the last pass's `block_on`, stop before Phase 2 and write nothing: "Nothing new since pass 2 (9719a72, 2026-09-29 18:04), which found nothing blocking. Pass --full to review it again."

## State

```bash
STATE_DIR="$(git rev-parse --path-format=absolute --git-common-dir)/super-code-review"
BRANCH=$(git rev-parse --abbrev-ref HEAD)        # "HEAD" when detached
KEY="pr-$PR"                                     # PR mode
SLUG=$(printf %s "$BRANCH" | tr -c 'A-Za-z0-9._-' '-')
HASH=$(printf %s "$BRANCH" | shasum | cut -c1-8)
KEY="${MODE}-${SLUG}-${HASH}"                    # range / working mode, on a branch
STATE="$STATE_DIR/$KEY.json"
PATCH="$STATE_DIR/$KEY.last.patch"
```

The hash keeps `feat/a-b` and `feat-a/b` apart. The state file (write it with the Write tool after `mkdir -p "$STATE_DIR"`):

```json
{
  "schema_version": 2, "key": "pr-123", "series": "2026-09-29T18:04:11Z",
  "base_ref": "main", "large": false,
  "passes": [
    {"n": 1, "round": 1, "mode": "full", "effort": "high", "block_on": "major",
     "head_sha": "<full sha>", "at": "2026-09-29T18:04:11Z", "cap": 2, "blocked": true,
     "findings": [{"id": "fnd-1", "first_pass": 1, "severity": "blocker", "file": "src/limiter.rs",
       "line_start": 42, "line_end": 47, "title": "Refill overflows at u32::MAX",
       "blocking": true, "status": "open", "thread_url": null}],
     "submitted": {"event": "REQUEST_CHANGES", "review_id": 123456}}
  ]
}
```

`blocked` is true when any finding has `blocking: true`. A carried finding keeps its `id` and `first_pass`. This is the one exception to the read-only pipeline: the orchestrator, never a reviewer or validator agent, writes `<key>.json` and `<key>.last.patch` in the git dir, outside the worktree. An unreadable file, or one with a different `schema_version`, starts a new series; say so.

## Resolving the pass

Run this after Phase 1's diff-source step returns, since it needs the head SHA and PR number. In PR mode, the prior-feedback fetches (`prior-feedback.md`) run in parallel with the rest of Phase 1.

1. Read the state file.
2. In PR mode, read the skill's own marked reviews, and parse each marker's `series`, `pass`, `round`, `blocked`, `effort`, `base`, and `head`:

   ```bash
   ME=$(gh api user --jq .login)
   gh api --paginate "repos/$OWNER_REPO/pulls/$PR/reviews" \
     --jq ".[] | select(.user.login == \"$ME\" and (.body | test(\"^<!-- super-code-review series=\"))) | {id, state, commit_id, submitted_at, body}"
   ```

   The marker is anchored at the start of the body, so a review that quotes one doesn't match. When the newest marker names a newer series than the local file, adopt it, but only after the series checks pass against that marker's `head` and `base`. Within one series, the higher pass number wins.
3. The pass number is the last pass's `n` plus one, or 1 when there's no last pass. The round follows "Rounds". Count recorded passes, never reviews.
4. Compute the delta ("The delta"). A large delta starts a new series ("Series"); an empty one after a clean pass ends the run ("Nothing new since a clean pass").

## The cap

The cap is on rounds: 2, or 3 when the diff is large, at least 1000 changed lines or 30 changed files after skip-paths (`diff-sources.md` → "Skip-paths"), counted with `gh pr view "$PR" --json files --jq '[.files[] | {path, n: (.additions + .deletions)}]'` in PR mode and `git diff --numstat "$RANGE"` in range mode. `large` is stored on the series and never turns back to false within it. The same count on the delta alone (`$LAST_HEAD...$HEAD`, or the delta's files in working mode) decides whether the delta is large.

## Past the cap, ask the user

A round past the cap means blocking findings survived every round the cap allowed. Before Phase 2, run the carried-finding re-checks (below), then print what the series found, from the state file, the re-checks, and the delta, and ask the user (`AskUserQuestion` in Claude Code, `request_user_input` in Codex):

```text
Round cap reached on feat (cap 2; this would be pass 3, round 3).
- Pass 1 (round 1, full): 1 blocker — median returns the upper middle element for even-length input (calc.py:5-7); 1 major — the even-length path has no test (test_calc.py)
- Pass 2 (round 2, incremental): the blocker fixed; the major still open
- Still open: 1 major — the even-length path has no test (test_calc.py:12-30), open since pass 1 (2 rounds). Re-graded under the closing bar: still major, "the diff's core path has no test". Possibly miscalibrated: your call whether it's real or the bar moved.
- Since pass 2: 1 commit, calc.py (+4) — "add spread"
```

Name every blocking finding from the last pass and its status, and every re-graded finding with its new severity and why. When commits have landed since the last pass, recommend the closing round ("checks the fixes for …"); when none have, say so and recommend stopping, since a re-run on the same code re-finds the same things. Then ask:

1. **Closing round**: blocks only on blockers and regressions; re-graded findings keep their new severity.
2. **Round 1 again**: `--block-on` honored on everything, as on a first pass; the pass is recorded at round 1.
3. **Stop**: review nothing and record nothing.

Ask on every run past the cap. A host that can't ask (`lu`, a non-interactive run) runs the closing round and says in the output that the cap was reached and no one was asked.

## The delta

The delta is what changed since the last pass's head. Pick the first rule that applies.

1. **Line-level**: the old head is an ancestor of the new head, no merge commit sits between them, and (PR mode) the compare response is complete.
2. **File-level**: split the current normalized diff and `$PATCH` on `diff --git` headers; a file is in the delta when its per-file text differs or it's new.
3. **Whole diff**: no `$PATCH` either. The output says why.

PR mode needs no local objects:

```bash
gh api "repos/$OWNER_REPO/compare/$LAST_HEAD...$HEAD" \
  --jq '{status, n: (.files | length), merges: ([.commits[] | select((.parents | length) > 1)] | length), files: [.files[] | {filename, patch, additions, deletions}]}'
```

`status` `ahead` with `merges == 0` and `n < 300` gives a line-level delta; 300 files means GitHub truncated the list, so go file-level. `ahead` with merges keeps the series and goes file-level. `diverged`, `behind`, or a 404 means the old head was rewritten: new series.

Range mode:

```bash
git merge-base --is-ancestor "$LAST_HEAD" "$HEAD_SHA"   # 0: same series; 1: new series; other: error, say so, go file-level
git rev-list --merges --count "$LAST_HEAD..$HEAD_SHA"    # > 0: file-level
git diff "$LAST_HEAD" "$HEAD_SHA"                        # the line-level delta otherwise
```

Working-tree mode checks the series the same way against `HEAD`, but always uses the file-level delta: two runs on the same `HEAD` would give an empty line-level one. Nothing here writes to the index; no `git add -N`.

## Carried-finding re-checks

On pass 2 and later, every finding from the last pass is re-checked: `fixed`, `still-open`, or `regressed`, with a refreshed location. Read the file as the review source sees it: the file on disk in working-tree mode (untracked files included), `git show <head>:<path>` in PR and range mode, or the file via `gh api` when the head isn't local. Run one re-check agent per file (`agent-prompts.md` → "Carried-finding re-check template"), separate from the new-finding validators. At `low`, the orchestrator reads the cited lines itself.

**Re-grading.** A still-open blocking finding reported before the last pass (`first_pass < n`) has survived two rounds or more. The same agent re-grades it under the closing bar: blocker only when the code is definitely worse than the base, and it says why. Its new severity replaces the old one, and the output labels it "possibly miscalibrated" so the user decides whether it's real or the bar moved. On a run past the cap the re-checks run in Phase 1, ahead of the question; Phase 3 doesn't run them again.

## Non-blocking notes

A finding at or above the `--block-on` severity that doesn't block under the round's rule is a non-blocking note, in every round. With `--submit`, notes go in the review body under "Non-blocking:", one line each with a code link, never inline. With `--comment`, a note's bold lead is `**Non-blocking: <title>**` in place of the severity label. Findings below the threshold stay local, as they always have.

On a closing round, the local summary says the cap was reached and only blockers and regressions block, lists what's left as non-blocking with any re-grade and its reason, and says the remaining calls belong to a human. The posted text is in `submit.md`.

## Writing state

After Phase 5, append the pass record: `round`, `block_on`, `blocked`, `effort`, every finding's final `blocking` and `first_pass` (the current `n` for new findings), and `submitted: null`; overwrite `<key>.last.patch` with the normalized diff. After Phase 5b, fill in `submitted`; leave it `null` when the submission was skipped or failed. The pass counts either way.
