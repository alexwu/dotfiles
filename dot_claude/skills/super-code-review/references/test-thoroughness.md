# Test Thoroughness — Extended Catalog

Shared reference between the `test-thoroughness-reviewer` agent and the main orchestrator. The agent file has the core smell list; this file has language-specific examples and harder cases.

## Smell catalog by language

### Swift (XCTest / Testing)

**No-assertion test:**
```swift
// BAD
func testParse() {
    let result = MyParser.parse(input)
    // ... no XCTAssertEqual, no #expect
}

// GOOD
func testParse() {
    let result = MyParser.parse(input)
    XCTAssertEqual(result, expected)   // or with Testing: #expect(result == expected)
}
```

**Sleep-based timing:**
```swift
// BAD — flaky
try await Task.sleep(for: .seconds(1))
XCTAssertTrue(viewModel.isReady)

// GOOD — use confirmation (Testing framework) or a test clock
await confirmation { confirmed in
    viewModel.onReady = { confirmed() }
    viewModel.start()
}
```

**Over-mocked integration:**
```swift
// BAD — mocking the very thing under test
let mockDB = MockDatabase()
mockDB.shouldThrow = .duplicateKey
sut.save(user, db: mockDB)
// ... testing that we call the mock; not testing real DB behavior
```

If `pfw-testing` skill is loaded, defer to its patterns for `confirmation`, `@MainActor`, `.serialized` trait usage.

### Rust

**`#[should_panic]` without panic message check:**
```rust
// WEAK — passes on any panic
#[test]
#[should_panic]
fn test_overflow() { /* ... */ }

// STRONG — only passes on the expected panic
#[test]
#[should_panic(expected = "overflow")]
fn test_overflow() { /* ... */ }
```

**`unwrap()` in tests masking real assertion intent:**
```rust
// BAD — unwrap hides what we're checking
assert_eq!(parse(s).unwrap(), expected);   // panics on parse error instead of asserting Ok-ness

// GOOD
let parsed = parse(s).expect("parse should succeed for valid input");
assert_eq!(parsed, expected);
```

### TS / JS (Jest / Vitest)

**Tautological `toBeDefined`:**
```typescript
// BAD — checks nothing about content
expect(result).toBeDefined();

// GOOD
expect(result).toEqual({ status: "ok", count: 3 });
```

**`async` test missing `await` on the assertion:**
```typescript
// BAD — promise never resolves before test exits
test("fetches user", () => {
    expect(fetchUser(id)).resolves.toEqual(expectedUser);   // no await/return
});

// GOOD
test("fetches user", async () => {
    await expect(fetchUser(id)).resolves.toEqual(expectedUser);
});
```

### Python (pytest / unittest)

**`assert` in test with no message and no expected pattern:**
```python
# WEAK
assert result

# STRONG
assert result == expected, f"expected {expected}, got {result}"
```

**Catching the very exception under test:**
```python
# BAD
def test_raises_on_empty():
    try:
        parse("")
    except ValueError:
        pass   # passes whether or not the right thing happened

# GOOD
def test_raises_on_empty():
    with pytest.raises(ValueError, match="empty input"):
        parse("")
```

### Nim (`unittest` / `testament`)

**`check` with no expression:**
```nim
# BAD
check parse(s) != nil

# GOOD
let parsed = parse(s)
check parsed.kind == nkLiteral
check parsed.value == 42
```

## Cross-language smells

These apply regardless of framework:

- **Happy-path-only**: no nil/empty/boundary/error-path coverage
- **Hardcoded fixture drift**: golden file or fixture changed without an accompanying assertion change
- **Snapshot-only on dynamic data**: snapshot includes timestamp/UUID/random without normalization → guaranteed flaky
- **Implementation tests**: asserts internal call counts (`mock.foo.callCount == 2`) instead of observable output
- **Test that never fails on real bugs**: catches the exception under test silently, asserts something always true, or has commented-out assertions
- **One-test-per-method habit**: tests named after method names but actually testing the same flow N times with trivial input variation

## Coverage vs. behavior

Test coverage tools (`llvm-cov`, `nyc`, `pytest-cov`) measure line coverage. Don't use them as a thoroughness signal — a 100% line-coverage test suite can still be useless if every test is a no-assertion test. Behavior coverage is what matters: does the test fail when the behavior breaks?

Quick mental model the reviewer should apply:
> "If I mutated this line of the source under test, would any test fail?"

If the answer is "no" for a meaningful change, the tests aren't thorough enough.

## When *not* to flag missing tests

- The diff is a rename refactor with no behavior change
- The diff is a comment-only or formatting-only change
- The diff is in a `__tests__` / test-only directory and the tests themselves are the change
- The diff is in a generated file
- The repo's CLAUDE.md or convention explicitly allows tests-later

## Suggestion text shape

When the test-thoroughness-reviewer recommends a missing test, it should be **concrete enough to write**, but **not a full code example** (the user is the author, not the reviewer):

```
suggestion: "Add a test for the empty-string input case — currently parse("") falls through to a nil return; assert the caller's behavior on nil."
```

Not:
```
suggestion: "Improve test coverage."   # useless
```

Not:
```
suggestion: |
   func testEmptyParse() {
       XCTAssertNil(parse(""))
   }                                   # writing the code for them is overstepping
```
