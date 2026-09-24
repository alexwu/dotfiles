# Tooling

Versions confirmed against rubygems.org on 2026-09-21.

## Who owns which decision

| Decision | Owner |
|---|---|
| Indentation, quotes, brace spacing, chain layout, `if`-assignment shape | **rubyfmt** |
| **Where lines break** | **you** — rubyfmt does not wrap |
| Max line length (100) | **RuboCop** `Layout/LineLength` |
| Semantics (`fetch` vs `[]`, `class << self`, dead code, Ruby-3 cops) | **RuboCop** |
| Types | **`srb tc`** |
| Editor plumbing (definitions, hover, symbols) | **ruby-lsp** |

The failure mode is two tools owning one decision and churning against each
other on every save. `rubocop-rubyfmt` exists specifically to stop that.

## rubyfmt

**It is a Rust binary from Homebrew, not a gem.** The `rubyfmt` gem on
rubygems.org is an unrelated abandoned 2014 project — never put it in a
Gemfile. CI installs the binary.

```sh
brew install rubyfmt
rubyfmt -i path/to/file.rb        # format in place
rubyfmt -c path/to/file.rb        # check mode — diffs to stdout, non-zero on drift
rubyfmt lib/                      # directories work
cat foo.rb | rubyfmt              # stdin; pair with --stdin-filepath for ignore rules
```

Other flags: `--header-opt-in` / `--header-opt-out` (respect a magic
`# rubyfmt: true|false` header), `--fail-fast`, `--include-gitignored`.
Honors `.rubyfmtignore` and `.gitignore`.

**Version:** 0.14.1 is genuinely current — Homebrew's formula fetches
`v0.14.1`, the repo's `Cargo.toml` on `trunk` still declares `0.14.1`, and
`rubyfmt --version` agrees. A `v0.14.2-10` tag exists upstream but is an
internal pre-release marker for unshipped work; don't read it as "you're
behind."

**Maintenance:** explicit "no lead maintainer" model — the original author
stepped back and contributors with commit access merge what passes CI. Last
`trunk` commit 2026-08-10, steady modest cadence, 23 open issues being triaged.
Not abandoned; not thriving. It parses via **Prism**, so Ruby 3.4/4.0 syntax
works — verified locally: endless methods, `{x:, y:}`, `case/in`, `Data.define`,
`it`, and `def f(&)` all survive a round-trip intact.


**`rubocop-rubyfmt` also ships a custom cop you want.** rubyfmt only understands
comments on their own line, so it *relocates* a trailing comment up one line —
turning a scoped disable into an unterminated, file-wide one. Verified:

```ruby
foo = bar # rubocop:disable Some/Lint   # in
# rubocop:disable Some/Lint            # out — no matching enable, applies to EOF
foo = bar

# rubocop:disable Some/Lint            # this is the form that survives
foo
# rubocop:enable Some/Lint
```

`Rubyfmt/NoEndOfLineRubocopDisables` catches it and autocorrects. When adopting
rubyfmt on an existing repo, codemod first:
`bundle exec rubocop --autocorrect --only Rubyfmt/NoEndOfLineRubocopDisables`.
Note the gem only suppresses violations *caused by* rubyfmt — a method body that
gets longer after formatting can still trip `Metrics/MethodLength`.

**Alternative if rubyfmt ever stalls:** `syntax_tree` (pure Ruby, v6.3.0, last
commit 2026-05-03) ships the same kind of RuboCop-disabling config and *is* a
first-class ruby-lsp formatter — which rubyfmt is not.

## RuboCop

RuboCop 1.91.0; `rubocop-shopify` 3.1.0; `rubocop-rubyfmt` 0.1.2 (2026-09-09);
`rubocop-sorbet` 0.16.0; `rubocop-rspec` 3.10.2; `rubocop-rails` 2.38.0.

`Gemfile`:

```ruby
group :development, :test do
  gem "rubocop", require: false
  gem "rubocop-shopify", require: false
  gem "rubocop-rubyfmt", require: false
  gem "rubocop-sorbet", require: false
  gem "rubocop-rspec", require: false
end
```

`.rubocop.yml` — inherit, then override. **Local declarations win over an
inherited gem**, so the `Layout/LineLength` block below is what actually sets
the limit:

```yaml
inherit_gem:
  rubocop-shopify: rubocop.yml

plugins:
  - rubocop-rubyfmt      # a plugin, NOT an inherit_gem entry
  - rubocop-sorbet
  - rubocop-rspec

inherit_mode:
  merge:
    - Exclude

AllCops:
  TargetRubyVersion: 3.2        # match .ruby-version — rubocop-shopify sets none
  NewCops: enable               # rubocop-shopify sets `disable`; opt back in if you want them

# rubocop-shopify disables this cop entirely. 100 is the house number.
Layout/LineLength:
  Enabled: true
  Max: 100
```

Three things about `rubocop-shopify` that surprise people:

1. **It deliberately stopped enforcing style.** "The great reset" (PR #687,
   merged 2025-02-19) disabled nearly every cop on purpose. From the PR body:
   *"Before, we would restrict the expressiveness of Ruby for the sake of
   consistency and safety. This was causing Ruby programs that felt not really
   like Ruby."* Everything was turned off except `Style/FrozenStringLiteralComment`
   and a few Bundler/Gemspec cops; the ~37 now enabled were re-added one at a
   time on correctness grounds. So `Layout/LineLength`, `StringLiterals`, every
   `TrailingComma`, `BlockDelimiters` and **all `Metrics/*`** are off by
   design, not by oversight. Read the YAML before claiming a rule is live.
2. **It sets no `TargetRubyVersion`** — it defers to your `.ruby-version` /
   gemspec. Inheriting it does not pin a Ruby version for you.
3. **It sets `NewCops: disable`** — new cops are opt-in by design, triaged by
   the style-guide maintainers rather than auto-enabled on upgrade.

The survivors are semantic and notably modern: `Style/EndlessMethod`,
`Style/ClassMethodsDefinitions` (`self_class`), `Lint/DataDefineOverride`,
`Lint/DuplicateMatchPattern`, `Lint/UnreachablePatternBranch`,
`Style/TallyMethod`, `Style/DigChain`, `Style/SelectByKind`, plus its two
custom cops `Lint/NoReturnInMemoization` and `Style/ProcCaseWhen`.

**What Shopify itself formats with: RuboCop.** `ruby-lsp`'s `detect_formatter`
picks `rubocop_internal` when *any* direct dependency matches `/^rubocop/`
(which `rubocop-shopify` does), falls back to `syntax_tree` only when RuboCop
isn't a direct dep, else `none`. rubyfmt appears nowhere in `ruby-lsp`. So the
disabled Layout cops aren't "making room for a formatter" — they're making room
for **RuboCop's own autocorrect** plus human judgment. Using rubyfmt here is a
deliberate local choice, which is exactly why `rubocop-rubyfmt` is needed to
keep the two from re-litigating each other.
**`.rubocop_todo.yml` for an existing codebase:** `rubocop --auto-gen-config`
snapshots every current offense into the todo file, then `.rubocop.yml` does
`inherit_from: .rubocop_todo.yml`. Burn entries down over time. This is how you
adopt a config without a wall of red — see `brownfield.md`.

## Sorbet

```sh
bin/tapioca gems                    # gem RBIs → sorbet/rbi/gems/ (commit)
bin/tapioca dsl                     # runtime-generated method RBIs → sorbet/rbi/dsl/
bin/tapioca dsl --verify            # CI gate — fails on stale RBIs, writes nothing
bundle exec srb tc                  # the check
```

`sorbet/config`, one flag per line (`editorder`'s, abridged):

```
--dir
.
--ignore=tmp/
--ignore=node_modules/
--ignore=db/migrate/
--ignore=db/schema.rb
--ignore=bin
```

## ruby-lsp

`ruby-lsp` 0.26.11 stable (0.27 is in beta — don't mandate it).
Add-ons: `ruby-lsp-rspec` 0.1.29 (2026-03-05); `ruby-lsp-rails` 0.4.8 — note
that one last released 2025-07-18, over a year behind core, so confirm it still
works against your ruby-lsp before mandating it.
**There is no `ruby-lsp-sorbet` gem** — don't tell anyone to install one.

**Formatter selection is the gotcha.** `rubyLsp.formatter` defaults to
`"auto"`, which resolves to **RuboCop if it's in the bundle, else
`syntax_tree`, else nothing**. rubyfmt is not first-party and will never be
picked automatically. Either accept RuboCop-as-formatter in the editor, or set
`"formatter": "none"` and run rubyfmt from a save hook — which is what
`editorder` does via `./bin/setup-claude`.

```jsonc
{
  "rubyLsp": {
    "formatter": "none",
    "enabledFeatures": { "diagnostics": true },
    "addonSettings": { "Ruby LSP Rails": { "enablePendingMigrationsPrompt": false } }
  },
  "[ruby]": { "editor.formatOnSave": true }
}
```

## RSpec

`rspec-core` 3.13.6. `.rspec`:

```
--color
--require spec_helper
```

`spec_helper.rb`, if you're taking Option A from `testing.md`:

```ruby
require "rspec/sorbet"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
end

RSpec::Sorbet.allow_doubles!
```

## A CI gate that covers all four

```sh
rubyfmt -c $(git ls-files '*.rb')     # formatting drift
bundle exec rubocop                   # semantics + line length
bin/tapioca dsl --verify              # RBIs not stale
bundle exec srb tc                    # types
bundle exec rspec                     # tests
```

Wrap the read-only ones in `memo` locally so a re-run is free; `chain` them
when you want unambiguous per-step banners.

## Gem staleness in `editorder` (as of 2026-09-21)

Worth knowing before you recommend a cop or an API there:

| Gem | Pinned | Current | Gap |
|---|---|---|---|
| `rubocop` | 1.59.0 | 1.91.0 | ~2 yr 9 mo |
| `rubocop-rails` | 2.23.1 | 2.38.0 | ~2 yr 9 mo |
| `rails` | 7.2.3 | 8.1.3.1 | a full major |
| `tapioca` | 0.17.10 | 0.20.0 | ~9 mo |
| `sorbet-runtime` | 0.6.12984 | 0.6.13506 | ~6 mo (daily releases — minor) |
| `rspec-core` / `rspec-rails` | 3.13.6 / 8.0.4 | same | current |

RuboCop 1.59.0 predates the Prism transition entirely, so any cop you cite
needs checking against *that* version's cop list before you promise it exists.
Gate any Rails-8 API behind "confirm the app has upgraded."
