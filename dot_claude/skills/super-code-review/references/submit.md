# Submit (`--submit`, `--block-on`)

`--submit` turns the review into a verdict on the PR. After the normal pipeline (Phases 1-5), a Fable agent re-validates the merged findings. If any surviving finding is at or above the `--block-on` threshold, the skill submits a GitHub review that **requests changes**, with those findings as inline comments. Otherwise it submits an **approval**. The submission is automatic: no confirmation step.

GitHub only. PR mode only. In range or working-tree mode, `--submit` is ignored with a one-line warning, and the review prints as usual.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--submit` | off | Validate with Fable, then approve or request changes on the PR |
| `--block-on <major\|all>` | `major` | `major`: blockers and majors trigger request-changes. `all`: every surviving finding does, suggestions included |

`--submit` replaces `--comment`: the review carries its own inline comments, so passing both posts one review, not a review plus loose comments.

`--block-on` without `--submit` has no effect; say so in one line.

## Procedure

### 1. Preconditions

Run these before spawning anything:

```bash
gh pr view "$PR" --json number,headRefOid,author,url \
  --jq '{number, head: .headRefOid, author: .author.login, url}'
gh repo view --json nameWithOwner --jq .nameWithOwner   # owner/repo
gh api user --jq .login                                  # who's submitting
```

Record the head SHA. It's the `commit_id` of the review, and step 5 checks that it hasn't moved.

### 2. Fable validation

Spawn **one** `general-purpose` agent with `model: "fable"`, using the Fable validator template in `agent-prompts.md`. Set the model explicitly. It's the reason this step exists; an unset model inherits the session's.

It receives every merged finding from Phase 4 **except** `user_rule_notes` (those are never posted and never count), plus the diff path and PR metadata. For each finding it returns: keep or kill, the severity it confirms (it may change a severity and must say why), and whether the cited lines sit on the right-hand side of a diff hunk (`inline: true|false`).

When there are more than 15 findings, split them by file across several Fable agents in one message, so they run in parallel.

**If the Fable agent can't run** (the model is unavailable, the spawn errors): don't submit. Print the normal review, and say that the verdict wasn't submitted because the Fable validation couldn't run. Never submit on the strength of Phase 3 validation alone; the Fable pass is the point of the flag.

### 3. Decide

- **Threshold:** `major` → `{blocker, major}`. `all` → `{blocker, major, suggestion}`.
- **Escalated** = findings Fable kept whose confirmed severity is in the threshold.
- Escalated is non-empty → `REQUEST_CHANGES`. Empty → `APPROVE`.

Findings below the threshold are not posted. They stay in the local summary.

**Your own PR.** When the PR author and the `gh api user` login match, submit with event `COMMENT` instead, and open the body with the verdict it would have been: `Would request changes:` or `Would approve:`. Say so in the local output.

### 4. Write the review text

**Load the `writing-english` skill first**, and write every word that gets posted under its rules: the review body and each inline comment. These go out under the user's name.

- **Review body, request changes:** one or two sentences naming what blocks the merge, then a count ("3 issues inline"). Findings that can't be inline (step 5) go here, each with a code link in the `output-formats.md` format.
- **Review body, approve:** two to four sentences on what the review checked and found sound. No pipeline details.
- **Each inline comment:** what's wrong, the concrete failure (input → wrong result), and the fix direction. Add a committable `suggestion` block only under the rules in `output-formats.md` → "Committable suggestion blocks".

Keep the pipeline out of the posted text: no reviewer names, no "validated by", no "Codex found", no local paths, no scratchpad files, no severity-tier jargon beyond a plain label ("Blocking:", "Should fix:"). The reader is the PR author, not the pipeline.

### 5. Build and post

Check the head hasn't moved since step 1:

```bash
gh pr view "$PR" --json headRefOid --jq .headRefOid
```

If it changed, the review covers stale code. Don't submit; tell the user the PR moved and that the review needs a rerun.

Build the payload with the Write tool into the scratchpad directory, one comment object per escalated finding with `inline: true`:

```json
{
  "commit_id": "<head SHA from step 1>",
  "event": "REQUEST_CHANGES",
  "body": "<review body>",
  "comments": [
    {
      "path": "src/limiter.rs",
      "start_line": 42,
      "start_side": "RIGHT",
      "line": 47,
      "side": "RIGHT",
      "body": "<comment>"
    }
  ]
}
```

Single-line comments omit `start_line` and `start_side`. Don't use `position`; GitHub deprecated it in favor of `line`. Never omit `event`: a review without one is left pending and invisible to the author.

Findings with `inline: false` (the cited lines aren't in a diff hunk) go into the body, not `comments`. A comment on a line outside the diff makes GitHub reject the whole review.

```bash
gh api --method POST "repos/$OWNER_REPO/pulls/$PR/reviews" --input "$PAYLOAD" \
  --jq '{id, state, html_url}'
```

### 6. Errors

- **422 naming a comment's line or path:** move the named comments into the body and retry **once**. A 422 means no review was created, so a retry can't double-post.
- **Any other error:** stop. Report the status and message. Don't retry, and don't fall back to loose comments.
- **Delete the payload file** after the call, whatever the result.

### 7. Report

Print the normal local summary (Phase 5), then one line:

```text
Submitted: REQUEST_CHANGES (3 inline, 1 in body) — https://github.com/owner/repo/pull/123#pullrequestreview-…
```

For `--json`, add the `submission` object from `output-formats.md`.
