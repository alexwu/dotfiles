---
name: writing-pr-descriptions
description: Creates GitHub pull request descriptions and titles following Conventional Commit format. Use after completing code changes that need PR documentation. Triggered by "PR description", "pull request", "create PR", or "write PR".
---

# Writing PR Descriptions

Creates clear, dry, factual GitHub PR descriptions and titles. No promotional language or subjective assessments.

## Workflow

1. Run `git diff main...HEAD` to see all changes for the PR
2. Run `git log main..HEAD --oneline` to see commit history
3. Capture coordinates for permalinks (used in step 6):
   - Owner/repo: `gh repo view --json nameWithOwner -q .nameWithOwner` → e.g. `alexwu/lulu-app`
   - PR-head SHA: `git rev-parse HEAD`
   - If the branch isn't pushed yet, push it first — permalinks resolve against SHAs GitHub knows about, so an unpushed SHA 404s
4. Identify the primary change type and scope
5. Write title in Conventional Commit format
6. Write description following the structure below, using permalinks for any specific file/line reference

## PR Title Format

```
type(scope): Description in present tense
```

- **Types:** feat, fix, chore, docs, style, refactor, perf, test
- **Scope:** Feature-level scope in parentheses
- **Capitalize** first letter of description

## PR Description Structure

```markdown
Brief factual statement of what this PR implements or fixes. Ref: #[issue]

Requires `Flipper[Feature::Flag]` (if applicable)

## Notable changes
- Change one with `code references`
- Change two
- Change three

## QA steps
**Setup:** preconditions the tester needs

1. First action
2. Second action

**Expected:** what success looks like
```

## What Belongs in "Notable changes"

The PR description captures the **net change between `main` and the branch**, not the development journey. The reviewer doesn't care that you went down a wrong path and came back — they care about what they're being asked to merge.

Apply these tests when picking bullets:

- **Bug fixes:** include only if the bug existed in `main` before this branch. If you introduced the bug mid-branch and squashed it before pushing, it isn't a fix — it never reached the codebase. Listing it just narrates your debugging session.
- **Gotchas:** call out non-obvious behavior a reviewer or future maintainer could trip on — a new invariant callers must uphold, a migration that must run before deploy, a method that now mutates its input, an ordering constraint between calls, a known-acceptable performance regression. If it's surprising and load-bearing, it earns a bullet (or its own `## Notes` / `## Caveats` section if there are several).
- **Normal additions and changes:** the actual feature, refactor, schema change, or pre-existing-bug fix. Always.

**Examples:**
- ❌ "Fix infinite loop in `process_batch`" — when the loop bug was introduced and resolved within this branch
- ✅ "Fix off-by-one in `paginate` that dropped the last page" — pre-existing in `main`, surfaced by the new caller in this PR
- ✅ "`UserRepo#save` now mutates the passed-in record" — gotcha; existing callers need to know

## QA Steps

Add a `## QA steps` section so a non-engineer can verify the change end-to-end. Match the format to how the change is actually experienced — the goal is the lowest-jargon path a tester could reasonably follow given the app's shape:

- **Web / mobile / desktop UI:** click-by-click in plain language. **Bold** the labels the tester needs to find on screen ("click **Billing** in the left nav"). Don't reference URLs, route names, component names, or DOM ids — those are implementation details a non-engineer can't act on. State preconditions explicitly ("you need a logged-in user with no active subscription").
- **CLI tool:** copy-pasteable commands, no elision. Show a representative line of expected output (don't paste a whole table). State env vars, required binaries, and working directory up front.
- **HTTP API / library / background job / migration / build tooling:** there's no non-engineer path. Write it for the engineer reviewer — `curl` snippet, fixture setup, test invocation, or job command. Labeling the section "Engineer QA" is fine; the honesty about the floor is the point.

Each step block follows the same shape: **Setup** (preconditions) → **numbered steps** (one action each) → **Expected** (what success looks like, inline after each step or as a final bullet).

For bug-fix PRs, include a brief **Reproducing the bug (against `main`)** sub-block if the bug is reproducible without writing code — it proves the fix isn't a no-op.

**Omit the section only when there's genuinely nothing to verify** — a build-config tweak with no runtime effect, a dead-code deletion, a comment-only change. If in doubt, write the steps.

## Formatting Rules

- Backticks for ALL code: `ClassName`, `method_name`, `file/path.rb`, `table_name`
- Bullet points (- ) for lists
- `##` headers for sections

## Issue References

GitHub auto-closes linked issues on merge when the body uses one of: `Fixes`, `Closes`, `Resolves`. Pick based on whether this PR fully resolves the issue:

- **`Fixes #123` / `Closes #123` / `Resolves #123`** — PR fully resolves the issue; want auto-close
- **`Ref: #123`** — partial work, related context, or cross-reference; no auto-close
- **Cross-repo:** `Fixes org/repo#123` works the same way

Why it matters: silently auto-closing an issue that isn't actually done strands the remaining work without a tracker. The default should be `Ref:` unless the PR genuinely lands the whole thing.

## GitHub File/Line References

When a "Notable changes" bullet points at specific code, use a **full GitHub permalink pinned to the PR-head SHA** rather than a backticked path. GitHub renders the permalink as an inline code preview when reviewers hover/click it, which is the whole point — the description becomes navigable instead of just descriptive.

**Format:**

```
[`SymbolOrLabel`](https://github.com/<owner>/<repo>/blob/<sha>/<path>#L<start>-L<end>)
```

- `<sha>` — the PR-head SHA captured in workflow step 3. **Never** use a branch name (`blob/feature-x/...`) — branches move and the link rots after rebases or branch deletion.
- `#L42` for a single line, `#L42-L58` for a range.
- Label text inside the backticks should be the symbol the reader cares about (`BillingController#show`, `Subscription.current`), not the raw path. Path is in the URL.
- Backticked-path-only (no link) is acceptable when the file is referenced *generally* — e.g. "Add test coverage in `spec/controllers/billing_controller_spec.rb`" where no specific line matters.

**When to skip permalinks entirely:** the origin remote isn't GitHub (GitLab, Gitea, internal host) — fall back to backticked `path:line` refs. Note this in the PR if reviewers might expect links.

## Tone Guidelines

- **Do:** State facts without adjectives
- **Don't:** "greatly improves", "enhances", "makes it easier"
- **Do:** "Adds cancellation endpoint"
- **Don't:** "Adds a convenient new cancellation endpoint"

## Examples

### Feature PR
**Changes:** Added user dashboard with activity feed, notifications panel, settings page

**Title:** `feat(dashboard): Adds user dashboard with activity feed`

**Description:**
```markdown
Implements user dashboard functionality with activity tracking and notifications. Ref: #456

## Notable changes
- Add `DashboardController` with index and settings actions
- Create `ActivityFeed` component for displaying user actions
- Add `notifications` table with user foreign key
- Implement `NotificationService` for push notifications
```

### Bug Fix PR
**Changes:** Fixed null pointer when user has no subscription

**Title:** `fix(billing): Handles missing subscription gracefully`

**Description:**
```markdown
Fixes crash when accessing billing page for users without active subscription. Fixes #789

## Notable changes
- Add nil check in [`BillingController#show`](https://github.com/alexwu/lulu-app/blob/abc1234/app/controllers/billing_controller.rb#L42-L58)
- Update [`Subscription.current`](https://github.com/alexwu/lulu-app/blob/abc1234/app/models/subscription.rb#L88) to return null object pattern
- Add test coverage in `spec/controllers/billing_controller_spec.rb`

## QA steps

**Setup:** A logged-in user with no active subscription. On staging, the seeded account `qa-no-sub@example.com` is set up this way.

1. Sign in as `qa-no-sub@example.com`.
2. Click **Billing** in the left navigation.

**Expected:** The Billing page loads and shows "No active subscription — start a plan" instead of a blank page or an error.

**Reproducing the bug (against `main`):** Same steps — the Billing page returns a 500 error.
```

Permalinks point at the PR-head SHA (`abc1234` here would be the real `git rev-parse HEAD` output). The third bullet uses a backticked path because no specific line matters — the whole new file is the change. The QA section is written so a non-engineer teammate can follow it; no route names or controller names appear.

### Refactor PR
**Changes:** Extracted payment logic into service objects

**Title:** `refactor(payments): Extracts payment processing to service objects`

**Description:**
```markdown
Moves payment processing logic from controllers to dedicated service classes.

## Notable changes
- Create `PaymentProcessingService` from `PaymentsController` logic
- Create `RefundService` from `RefundsController` logic
- Update controllers to use new services
- Add unit tests for extracted services
```

## Anti-patterns

- ❌ "This PR greatly improves..." → ✅ "Implements..."
- ❌ "Added some fixes" → ✅ "Fixes null handling in `UserService`"
- ❌ Long paragraphs explaining why → ✅ Bullet list of what changed
- ❌ `` `app/foo.rb:42` `` (bare path:line, not navigable) → ✅ `[``foo#bar``](https://github.com/<owner>/<repo>/blob/<sha>/app/foo.rb#L42)`
- ❌ Permalink pinned to a branch name (rots on rebase) → ✅ Permalink pinned to the PR-head SHA
- ❌ `Fixes #N` when the PR only partially addresses the issue (auto-closes prematurely) → ✅ `Ref: #N`
- ❌ Listing bugs you introduced and squashed within the branch as "fixes" (narrates your debugging) → ✅ Only list fixes for bugs that existed in `main`
- ❌ QA steps written in engineer-jargon ("POST to `/api/billing`") when a non-engineer could test it → ✅ Click-by-click with **bolded UI labels** ("click **Billing** in the left nav")
- ❌ QA steps that skip preconditions and assume the tester already has the right state → ✅ Explicit **Setup** block listing what they need before step 1
