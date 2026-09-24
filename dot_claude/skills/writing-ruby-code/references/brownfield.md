# Brownfield — retrofitting into existing Ruby

The boy-scout rule with hard edges: **raise what you touch, never rewrite the
neighborhood.** A "make it idiomatic" sweep is its own deliberate task with its
own review — not something to slip into a bug fix, and not something to propose
uninvited.

## Order of operations

Do these one at a time, each its own commit, each verified before the next.
Stacking them produces a diff nobody can review.

1. **Formatter first.** `rubyfmt -i` across the target files, committed alone
   as `style(scope): Applies rubyfmt`. It touches everything and reviewing it
   mixed with logic is impossible. Add the SHA to `.git-blame-ignore-revs`
   (`editorder` already has one).
2. **RuboCop config, with a todo file.** Wire `inherit_gem` + your
   `Layout/LineLength`, then `rubocop --auto-gen-config` to snapshot existing
   offenses into `.rubocop_todo.yml`. Green CI on day one; burn entries down
   later. Never land a config change that turns CI red.
3. **Sigil raising**, file by file — see below.
4. **Behavior**, last and separately.

## Adoption is a dependency lift, not a version bump

Before proposing this skill's toolchain to an existing repo, check what's
actually in the Gemfile. `editorder` has **none** of `rubocop-shopify`,
`rubocop-rspec`, `rubocop-sorbet`, `rubyfmt`, or `syntax_tree` — so "wire up
the house config" there is net-new dependency adoption with its own review and
rollout, not a `bundle update`. Say that out loud rather than opening a PR that
adds five gems under a formatting-cleanup title.

Its RuboCop is also ~2 yr 9 mo stale (1.59.0, released 2023-12-11, vs 1.91.0).
That version predates RuboCop's whole Prism transition, so it cannot reliably
analyze newer-Ruby syntax. **Bundle the RuboCop bump with any Ruby upgrade** —
the two are not separable, and a cop you cite from current docs may simply not
exist in 1.59.0. Check before promising one.

## Raising a Sorbet sigil

`# typed: false` → `true` is the highest-value move, because `false` checks
nothing inside a method body. The procedure:

```sh
# 1. flip the sigil on ONE file
# 2. see what breaks
bundle exec srb tc --did-you-mean=false --ignore=vendor/
# 3. fix or annotate, re-run, commit that file alone
```

What the jump usually surfaces, in descending frequency:

- Untyped collaborators reached at call time (`SomeClient.new` inside a
  method). The fix is constructor injection, which is also the testability fix
  — do it rather than papering over with `T.unsafe`.
- Nilable returns that the code assumes are present. Prefer a guard clause or
  `fetch` over `T.must`; `T.must` is an assertion, not a silencer.
- Hash-shaped "records". Replace with a `T::Struct` (data only, named for the
  thing) rather than `T::Hash[Symbol, T.untyped]`.

`true` → `strict` is a bigger jump: every method needs a `sig` and every ivar
needs a `T.let`, including the awkward memoization declaration
(`@x = T.let(@x, T.nilable(String))` — see `sorbet.md`). Worth it for new
service objects, not worth forcing on a 900-line legacy class.

**Never raise a sigil across a whole directory in one commit.** The failures
interleave and you lose the ability to bisect.

## Reading an unfamiliar Ruby repo

Establish these before writing anything:

```sh
cat .ruby-version .tool-versions 2>/dev/null   # the version gate — do this first
rg -n 'TargetRubyVersion|inherit_gem|inherit_from' .rubocop.yml
eza -a .rubocop_todo.yml sorbet/ .rspec 2>/dev/null
rg -c '^# typed: (ignore|false|true|strict|strong)' app lib   # adoption level
rg -n 'rubyfmt|syntax_tree|stree' Gemfile justfile bin/ .github/ 2>/dev/null
cat .claude/rules/ruby/*.md 2>/dev/null        # repo-specific canon, if any
```

The sigil census tells you what posture the repo is in. `editorder` reads 1182
`true` / 532 `strict` / 159 `false` / 0 `strong` — a repo where `strict` is
normal and a new `false` file would be a regression. A repo with 90% `false` is
one where raising a single file is a real contribution.

## Pre-3.0 code — what to look for

The positional-hash → keyword-args separation (removed in 3.0) is the biggest
hazard in recently-ported code. Every trailing hash at a call site is suspect:

```ruby
def foo(a, b: 1); end
foo(1, {b: 2})     # worked pre-3.0, does not now
foo(1, **{b: 2})   # explicit splat
```

Also flag on sight: `tainted?`/`$SAFE` (dead), `Fixnum`/`Bignum` (removed 3.2),
`Dir.exists?` (removed 3.2), `Struct.new(keyword_init: true)` (redundant 3.2),
`Object#=~` on non-String/Regexp (raises 3.2), `require "readline"` (retired
3.3).

## What to leave alone

- A workaround with a comment explaining why. Check whether the underlying
  problem still exists before "fixing" it — but check, don't assume it doesn't.
- `.rubocop_todo.yml` entries unrelated to your change. They're a backlog, not
  a bug.
- Unfamiliar branches, stashes, or scratch files — they may be in-progress
  work. Investigate before deleting.
- A `# rubocop:disable` with a justification. A bare one with no reason is fair
  game to question, in its own commit.

## Never

- **Don't invent project history to justify the status quo.** The absence of
  `rubocop-shopify`, `rubyfmt`, or Sorbet from a repo is not evidence someone
  evaluated and rejected it. Check `git log`, `Gemfile` history, or ask.
- Don't land a formatter sweep and a behavior change in one commit.
- Don't add trailing commas "for consistency" — rubyfmt strips them (see
  `style.md`).
- Don't raise a sigil you can't get `srb tc` green on. A `# typed: true` file
  with six `T.unsafe` calls is worse than an honest `false`.
