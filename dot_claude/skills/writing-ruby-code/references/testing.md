# Testing (RSpec)

RSpec 3.13.x is current — there is no RSpec 4, so never pin `~> 4`.

## The collision nobody guesses

**`instance_double` and `sorbet-runtime` fight each other.** A verifying double
is an `RSpec::Mocks::InstanceVerifyingDouble`, not the real class, so passing
one into a `sig`'d parameter raises at runtime:

```
TypeError:
  Parameter 'client': Expected type HttpClient,
  got type RSpec::Mocks::InstanceVerifyingDouble with value #<InstanceDouble(HttpClient)>
```

This is not a bug in your code. It is the runtime sig doing its job. There are
exactly two ways out, and they lead to different test suites:

**Option A — teach Sorbet to accept doubles.** Add `rspec-sorbet` and one line
to `spec_helper.rb`:

```ruby
require "rspec/sorbet"
RSpec::Sorbet.allow_doubles!
```

Now `instance_double`/`class_double`/`object_double` pass sig validation.
**Caveat:** the gem is at 1.9.2, last released **2023-03-24** — ~3.5 years
stale, though with 8.5M downloads and a tiny surface area. It works by
relaxing `T::Configuration`'s call-validation handler.

**Option B — don't mock the object at all; mock the boundary.** This is
`editorder`'s choice, and the reasoning is worth understanding:

```ruby
# BAD — the whole object is a double, so Sorbet checks nothing.
#        Change KlaviyoClient#send_event's signature and this test still passes.
client = instance_double(KlaviyoClient)
allow(KlaviyoClient).to receive(:new).and_return(client)

# GOOD — the real object runs, only the HTTP call is faked.
#        Sorbet validates every signature along the way.
allow_any_instance_of(KlaviyoClient).to receive(:make_request).and_return(success_response)
```

Note this deliberately inverts the usual RSpec advice to avoid
`allow_any_instance_of` — the trade is "less idiomatic mocking, more real type
checking," and in a Sorbet codebase that trade is worth it. It requires the
class to *have* a boundary method to stub, which is itself a design pressure in
the right direction:

```ruby
class KlaviyoClient
  def send_event(data)
    handle_response(make_request("/events", data))
  end

  private

  def make_request(endpoint, data) = HTTP.post("#{BASE_URL}#{endpoint}", json: data)
end
```

**Pick A** for a greenfield suite that leans on verifying doubles everywhere.
**Pick B** in `editorder` and anywhere the point of the types is to catch
signature drift. Don't mix them silently — say which one the repo is on.

The deeper rule underneath both: **inject collaborators in the constructor.**
A class that takes `client:` needs neither option — the test passes a real fake
that implements the interface, and Sorbet type-checks the fake.

## Structure

- `expect` syntax only. `should` is disabled
  (`config.expect_with(:rspec) { |c| c.syntax = :expect }`).
- `let` is lazy and memoized per example; `let!` forces evaluation in a
  `before` hook. Reach for `let!` only when you need the side effect.
- **Prefer `let` to `@ivar` in a `before` block.** A typo'd `@ivar` silently
  returns `nil`; a typo'd `let` raises immediately with the name in the message.
- `described_class` instead of repeating the constant — it keeps shared
  examples polymorphic.
- Organize each example into setup / action / assertion paragraphs separated by
  blank lines. If you can't, the example is testing two things.
- **One *behavior* per example, not dogmatically one expectation.** When
  several assertions describe one behavior, `aggregate_failures` reports all of
  them instead of stopping at the first. (The one-expectation-per-example
  debate has no settled 2026 consensus — treat it as judgment, not a rule.)
- `--format documentation` when you want to read the output as a spec.

## Doubles

- `instance_double` / `class_double` / `object_double` over plain `double` —
  they verify the method exists with the right arity against the real class, so
  a renamed method fails the test instead of silently passing.
- Plain `double` only when there is no real class to verify against.
- `allow_any_instance_of` is an anti-pattern **except** for the Sorbet-boundary
  case above. If you reach for it anywhere else, inject a collaborator instead.

## `editorder` house rules

These are repo-specific and load-bearing there:

- **Fully qualify FactoryBot:** `FactoryBot.create(:shop)`, never bare
  `create(:shop)`.
- **Never hand-roll draft-order completion.** Use
  `FactoryBot.create(:order_from_draft_order, shop:, delay: 5, ...)` or
  `FactoryBot.create(:draft_order, :completed, ...)`. The factory has the
  delay-then-complete-with-retry built in; ad-hoc `sleep` + `rescue`-retry
  around `draft_order.complete` is flaky and gets copy-pasted everywhere.
- **Feature flags:** `stub_flipper(EO::F::Whatever) { double(enabled?: true) }`,
  never `Flipper.enable/disable` — the latter mutates global state and leaks
  between examples.
- **Never generate fake VCR cassettes.** They must come from real HTTP
  interactions. Use VCR for external APIs; mock for internal boundaries and
  hard-to-record interactions. Include error responses (429, 401, 500) in
  cassettes for external APIs.
- Find which cassette an example uses:
  `bundle exec rspec ./spec/foo_spec.rb:61 --dry-run --format documentation`.
- Feature specs test full integration — no mocking of internal components.

## Designing for testability

The rules that matter most are not in the spec file:

1. **Constructor injection.** `Foo.new(client:)` is testable; `Foo` calling
   `Client.new` inside a method is testable only by stubbing a constant.
2. **Keyword arguments.** `process(order:, notify: true)` reads at the call
   site and in the failure message; `process(order, true)` doesn't.
3. **Return values over side effects.** A method that returns a `Data` object
   is asserted with one `eq`. A method that writes to three places needs three
   mocks.
4. **Small objects.** If a spec needs six `let`s of setup, the object under
   test has six responsibilities.
5. **No `method_missing`, no monkeypatching core classes.** Both delete the
   seam a test would grab and the type Sorbet would check.

## Tooling

```sh
bundle exec rspec spec/path/to_spec.rb          # one file
bundle exec rspec spec/path/to_spec.rb:61       # one example
bundle exec srb tc --did-you-mean=false --ignore=vendor/   # then type-check
```

`.rspec` in `editorder`: `--color`, `--require spec_helper`, `--tag ~flaky`.
`rubocop-rspec` 3.10.2 and `ruby-lsp-rspec` 0.1.29 both exist and are current.
