# Prior Feedback

Everything already said on the PR, by anyone, read on every pass so nothing is reposted and nothing still open is lost. Load this file in PR mode, in Phase 1.

## Fetch

On every pass, pass 1 included, fetch all three, humans and bots alike:

```bash
# Every non-empty review body, from any reviewer
gh api --paginate "repos/$OWNER_REPO/pulls/$PR/reviews" \
  --jq '.[] | select(.body != "") | {user: .user.login, type: .user.type, state, submitted_at, body}'

# Every PR conversation comment (a PR is an issue for this endpoint)
gh api --paginate "repos/$OWNER_REPO/issues/$PR/comments" \
  --jq '.[] | {user: .user.login, type: .user.type, created_at, body, html_url}'

# Every review thread, with its comments
gh api graphql -f query='
  query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $number) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id isResolved isOutdated path line startLine originalLine
            comments(first: 100) {
              pageInfo { hasNextPage endCursor }
              nodes { author { login __typename } body createdAt url }
            }
          }
        }
      }
    }
  }' -F owner="${OWNER_REPO%/*}" -F name="${OWNER_REPO#*/}" -F number="$PR"
```

Repeat the thread query with `-F cursor=<endCursor>` while `hasNextPage` is true. A thread whose `comments.pageInfo.hasNextPage` is true gets the rest of its comments with:

```bash
gh api graphql -f query='
  query($id: ID!, $cursor: String) {
    node(id: $id) {
      ... on PullRequestReviewThread {
        comments(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes { author { login __typename } body createdAt url }
        }
      }
    }
  }' -F id="$THREAD_ID" -F cursor="$END_CURSOR"
```

Detect bots with `author.__typename == "Bot"`, never by login. Copilot is `copilot-pull-request-reviewer` in GraphQL and gains a `[bot]` suffix only in REST.

## Summary shape

Each item reaches the prompts as:

```json
{"kind": "thread | review | comment", "path": "src/limiter.rs", "lines": "42-47",
 "author": "coderabbitai", "is_bot": true, "resolved": false, "outdated": false,
 "first_comment": "<≤ 300 chars>", "last_comment": "<≤ 300 chars>", "url": "<link>"}
```

Review bodies and conversation comments have no `path`, `lines`, `resolved`, or `outdated`.

## Our own threads are carried findings

Threads opened by the skill's own marked reviews are already carried findings; the pass record holds their `thread_url`. Drop them from this list, so each item reaches the reviewers once.

## Matching

A finding matches a thread when the path is the same, the thread describes the same issue, and one of these holds:

- the line ranges overlap;
- the thread is outdated, so its old coordinates no longer map; match on path and issue;
- the finding is carried and its stored `thread_url` is that thread.

A match to an open thread suppresses the repost, never the verdict: the finding still counts toward blocking, and the review body links the thread.

## Resolved threads

A resolved thread whose issue is still present is raised again inline, linking the resolved thread, unless its last comment declines a non-blocker design point (`false-positives.md` → "A settled design thread"). A blocker is always raised again.

## Posted text

`submit.md` uses these lines in the review body. Write any variation under `writing-english`.

```markdown
Still open (thread by @coderabbitai): Refill overflows at u32::MAX — <thread link>

Non-blocking:
- `src/limiter.rs:42-47`: <title> — <code link>
```
