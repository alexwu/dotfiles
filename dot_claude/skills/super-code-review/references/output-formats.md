# Output Formats

Three output modes — default markdown summary, `--comment` for inline PR comments, `--json` for machine output.

## Default — markdown summary

Proper markdown. Readable in terminal, paste-friendly into GitHub / Slack / a doc. Not a rigid template — structure adapts to findings — but the **required elements** below must always appear in this order.

### Required structure

1. **H1 title** — `# Code Review — <PR title or "Working Tree" or "Branch: <name>">`
2. **Metadata block** — repo, branch, base/head SHA, pipeline (which reviewers ran), findings tally
3. **Intent sources line** — see below
4. **One-paragraph framing** — the diff's apparent scope and where the findings cluster (1-3 sentences). Skip if no findings.
5. **Severity-bucketed findings** — Blockers, Majors, Suggestions, each as an H2 section with emoji icon, only including buckets that have findings
6. **Invalidated findings** (when any were killed at validation) — collapsible-feeling H2 section
7. **"What's well covered" H2 section** — affirmative balance signal (see below for why this is required)
8. **"Recommended action" H2 section** — actionable end-summary tying findings to a fix path

### Citation rule — ironclad

**Every finding must cite explicit `file:line` or `file:line_start-line_end`.** Not "the `apply_added_corrections` loop." Not "`refresh_order_context`." The file path and the line range. Method names can appear in prose for readability, but the bracketed citation at the top of each finding is mandatory.

If the validator's input didn't carry line numbers, the orchestrator must derive them by re-reading the file before output — better to spend the read than to ship a finding the user can't jump to.

### Intent sources breadcrumb

After the metadata block, before findings:

```
**Intent sources**: PR body, linked issue #41, plan: `.claude/plans/customer-portal-phase2.md`
```

List exactly what was pulled. When nothing was pulled (intent was empty): `**Intent sources**: none — drift detection skipped`.

This isn't decoration. It's the receipt the user needs to spot-check: did we miss the actual spec? Is there a plan we didn't look at?

### Template (showing the shape, not the wording)

```markdown
# Code Review — <title>

**Repo**: `<owner>/<repo>`
**Branch**: `<head>` @ `<head-sha-short>` (base `<base>` @ `<base-sha-short>`)
**Pipeline**: <N> reviewers (<comma-list>) + <M> validators
**Findings**: <X> blockers, <Y> majors, <Z> suggestions, <K> invalidated

**Intent sources**: <list, or "none — drift detection skipped">

<One-paragraph framing of the diff and where the findings cluster.>

---

## 🟥 Blockers (must fix before merge)

### [1] <one-line title> — `path/to/file.ext:42-58`
**Discovered by**: <reviewer> *(or "reviewer + codex" when corroborated)*

<Body — what's wrong, why it's a blocker, what the failure mode looks like.>

**Fix**: <one-paragraph direction OR a code snippet ≤ 8 lines when the fix is small and unambiguous>

### [2] ...

## 🟧 Majors (should fix before merge)

### [3] ...

## 🟨 Suggestions

### [N] ...

---

## ✓ Invalidated findings

**[INVALID] <reviewer's claim>** — <one-sentence why it was killed at validation>

---

## What's well covered

<Bulleted list of things the review confirmed were correct — pre-existing patterns the diff handled right, test coverage that landed, scope-discipline observations. 3-8 bullets, no padding.>

---

## Recommended action

<2-4 sentence summary tying the findings to a fix order. Cluster related findings ("fixing [1]+[2] together..."). Name the tests from the Suggestions section that would lock in the blocker fixes.>
```

### When there are no findings

```markdown
# Code Review — <title>

**Repo**: `<owner>/<repo>`
**Branch**: ...
**Pipeline**: ...
**Findings**: 0 blockers, 0 majors, 0 suggestions

**Intent sources**: <list, or "none — drift detection skipped">

No issues found at high confidence.

## What's well covered

<3-5 bullets affirming what was checked and confirmed good.>
```

The "What's well covered" section is **required even on a clean review** — otherwise the user has no way to distinguish "we looked and found nothing" from "we looked superficially." This is the balance-signal that protects trust.

### Why the format isn't a strict template

The freeform-richer markdown above adapts naturally to findings — three blockers vs. zero blockers should look different. The orchestrator should generate what reads well, **provided every required element is present and every finding has an explicit `file:line` citation**.

If you find yourself wanting to add a section not listed above (e.g., "Performance notes", "Security implications"), do it — but place it before "Recommended action".

### Inline code suggestions

When a fix is small (≤ 8 lines), self-contained, and unambiguous, include a code fence:

````markdown
**Fix**: cap `share` at `[share, line_subtotal].min`:

```ruby
share = [(budget * expected / target_expected_total).round(2), line_subtotal].min
```
````

When the fix is larger or requires structural understanding, describe the direction in prose — don't write the code. "Describe direction, don't author the patch" applies whenever the fix touches more than a handful of lines or crosses files.

This shifts with effort tier: at `--effort=low`, **no inline code snippets** — descriptions only. At `medium` and `high`, snippets are allowed within the constraints above.

## `--comment` — inline PR comments

PR mode only. If invoked in range or working-tree mode, fall back to the markdown summary and warn.

### Posting mechanism

Two backends in priority order:

1. **MCP server** (`mcp__github_inline_comment__create_inline_comment`) — preferred if available. Use `confirmed: true`.
2. **Fallback** (`gh api`):

```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/$OWNER/$REPO/pulls/$PR_NUM/comments" \
  -f body="$COMMENT_BODY" \
  -f commit_id="$HEAD_SHA" \
  -f path="$FILE_PATH" \
  -F line=$LINE_NUM \
  -f side="RIGHT"
```

### Comment body format

```markdown
**<severity icon> <severity name>: <one-line description>**

<refined description, 1-2 sentences>

<optional code link to a referenced location, see format below>

<optional committable suggestion block — only when fix is ≤5 lines and fully self-contained>
```

### Code link format (critical — easy to get wrong)

```
https://github.com/<owner>/<repo>/blob/<full-40-char-sha>/<path>#L<start>-L<end>
```

Hard rules:

- **Full 40-char SHA**, not a short one, not `HEAD`, not a variable substitution
- Repo `<owner>/<repo>` must match the PR's repo exactly
- Line range format: `L<start>-L<end>` (capital L, single hyphen)
- Provide at least 1 line of context before and 1 after — for a comment about lines 5-6, link to `L4-L7`
- `#` between filename and line range, not a slash

Bad examples:
```
https://github.com/foo/bar/blob/main/file.ts#L5            (used branch ref — won't be stable)
https://github.com/foo/bar/blob/$(git rev-parse HEAD)/...  (shell substitution doesn't run in markdown)
https://github.com/foo/bar/blob/abc/file.ts#L5-6           (short sha, wrong range format)
```

### Committable suggestion blocks

Only when the fix is **fully self-contained** within the comment range:

````markdown
```suggestion
<corrected line(s) — exactly replaces the original>
```
````

Do NOT include a suggestion block when:
- The fix spans multiple files
- The fix requires understanding context outside the visible diff
- The fix is "rewrite this approach" rather than "change these lines"
- The fix is descriptive rather than prescriptive

If unsure, omit. A description-only comment is better than a misleading suggestion.

### One comment per unique issue

Hard rule. The orchestrator dedupes findings before posting; do NOT loop and re-post on API hiccups — surface each issue exactly once.

## `--json` — machine output

Structured output for CI consumption.

### Schema

```json
{
  "schema_version": "1.1",
  "source": {
    "mode": "pr | range | working",
    "base_sha": "abc123...",
    "head_sha": "def456..." | null,
    "pr_number": 1234,
    "pr_title": "..."
  },
  "intent_sources": ["pr_body", "issue:41", "plan:.claude/plans/foo.md"],
  "effort": "low | medium | high",
  "stats": {
    "files_reviewed": 12,
    "lines_added": 234,
    "lines_deleted": 88,
    "blockers": 1,
    "majors": 3,
    "suggestions": 5,
    "invalidated": 1
  },
  "findings": [
    {
      "id": "fnd-1",
      "severity": "blocker | major | suggestion",
      "title": "one-line title",
      "file": "path/to/file.ext",
      "line_start": 42,
      "line_end": 58,
      "type": "logic | type | claude-md | test-thoroughness | shortcut | drift | silent-failure | ...",
      "description": "<refined description>",
      "evidence": "<quoted line(s)>",
      "discovered_by": ["bug-reviewer", "codex"],
      "confidence": "high | medium",
      "validator_reasoning": "...",
      "fix_direction": "<prose>",
      "fix_snippet": "<code or null>",
      "rule_source": "path/to/CLAUDE.md (optional, claude-md type only)",
      "rule_quote": "verbatim rule (optional)"
    }
  ],
  "invalidated": [
    {"original_claim": "...", "reviewer": "...", "reason_killed": "..."}
  ],
  "well_covered": ["..."],
  "recommended_action": "<prose>",
  "gaps": [
    {"description": "couldn't verify X", "suggested_action": "..."}
  ],
  "second_opinion": {
    "agent": "codex:codex-rescue",
    "status": "ran | unavailable",
    "agreed_findings": 2,
    "unique_findings": 1
  },
  "coderabbit": {
    "ran": false,
    "findings_count": 0
  }
}
```

### Stdout vs file

When `--json` is set, write the JSON to stdout (machine-parseable) and write **nothing else** to stdout. Progress / status messages go to stderr.

If the user also passed `--output <path>`, write the JSON to that path and the markdown summary to stdout (they get both).

## Output mode combinations

- `--comment --json` — post inline AND emit JSON. Both happen.
- `--comment` (PR mode missing) — fall back to markdown summary, warn
- `--json` (no findings) — still emit valid JSON with empty `findings: []` and zero stats
