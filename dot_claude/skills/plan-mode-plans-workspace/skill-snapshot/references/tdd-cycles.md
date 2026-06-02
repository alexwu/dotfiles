# TDD Cycles (variant reference)

Loaded when the chosen variant has TDD enabled. Replaces the universal "Steps" section format in `SKILL.md` Phase 4 with red-green-refactor cycles, and adds TDD-specific exploration, rules, and self-containment checks.

**Core TDD principle:** If you didn't watch the test fail, you don't know if it tests the right thing. No production code without a failing test first.

## Additional Exploration Requirements (Phase 2)

Beyond the universal exploration in SKILL.md, also investigate:
- **Test framework and runner** — what testing framework does the project use? What's the test command?
- **Test file conventions** — where do tests live? Naming patterns? (`*.test.ts`, `*_test.go`, `tests/*.swift`, etc.)
- **Test helpers and fixtures** — what utilities, factories, or helpers exist for tests?
- **Existing test patterns** — how do similar tests in the codebase look? Match their style.

## Steps Section Format

Instead of the generic numbered steps in the base template, each feature/change is a TDD cycle:

````markdown
## Steps

### Cycle 1: [Behavior being tested]

**RED — Write failing test**

File: `tests/exact/path/test_file.ts`

```typescript
test('rejects empty email with validation error', () => {
  const result = validateEmail('');
  expect(result).toEqual({ valid: false, error: 'Email is required' });
});
```

**Verify RED**

```bash
npm test tests/exact/path/test_file.ts
```

Expected failure: `validateEmail is not defined` (function doesn't exist yet)

**GREEN — Minimal implementation**

File: `src/exact/path/validation.ts`

```typescript
export function validateEmail(email: string): ValidationResult {
  if (!email.trim()) {
    return { valid: false, error: 'Email is required' };
  }
  return { valid: true };
}
```

**Verify GREEN**

```bash
npm test tests/exact/path/test_file.ts
```

All tests pass.

**REFACTOR** (if needed)

[Describe any cleanup, or "None needed" if implementation is already clean]

**Commit**

```bash
git add src/exact/path/validation.ts tests/exact/path/test_file.ts
git commit -m "feat(validation): Add email presence validation"
```

---

### Cycle 2: [Next behavior]
...
````

## TDD Cycle Rules

These rules are non-negotiable in the plan:

### 1. Test code comes first in every cycle
The test snippet MUST appear before the implementation snippet. This isn't just formatting — it reflects the actual execution order.

### 2. Every cycle needs a verify step
Both RED and GREEN need explicit verification commands with expected output. The executing session must:
- Run the test and confirm it **fails for the right reason** (missing function, wrong return value — not a syntax error or import typo)
- Run the test again after implementation and confirm it **passes**

### 3. Minimal implementation only
The GREEN snippet should be the simplest code that makes the test pass. Don't add features, error handling, or refactoring that isn't required by the current test. Future cycles handle those.

### 4. One behavior per cycle
Each cycle tests ONE thing. If you find yourself writing "and" in the cycle name, split it.

### 5. Test must use real code — no mocks unless the user says so
Plan tests that exercise actual functions and return values. **Do not use mocks unless the user explicitly approves mocking for that project.** Some projects use request recording tools (VCR, OHHTTPStubs, etc.) — if the project has one, use that instead of mocks. If you're unsure, ask during Phase 3.

## Ordering Cycles

Structure cycles so each builds on the last:

1. **Happy path first** — the simplest valid case
2. **Edge cases** — empty input, boundaries, special characters
3. **Error cases** — invalid input, failure modes
4. **Integration** — how components work together

Each cycle should produce a commit. Frequent, small commits.

## What the Test Snippets Must Show

Same rules as base-skill code snippets — real code, not wishful thinking:

- Use actual function names, types, and test helpers found during exploration
- Match the project's existing test style and conventions
- Include imports if they're non-obvious
- Never write `// test the edge cases here` — write the actual assertions

**Good test (from exploration):**
```swift
@Test func streamClientDeliversChunks() async throws {
    let config = ElevenLabsConfiguration(apiKey: "test-key")
    let client = TTSStreamClient(configuration: config)
    let stream = try await client.stream(text: "Hello", voiceId: "test-voice")

    var chunks: [Data] = []
    for try await chunk in stream { chunks.append(chunk) }

    #expect(!chunks.isEmpty)
}
```

**Bad test (made up):**
```swift
@Test func itWorks() async throws {
    // Set up the client
    // Call the method
    // Assert it works
}
```

## Verification Placement

The base skill's required **Verification** section lives at the *end* of the plan, after all cycles complete. Per-cycle RED/GREEN verification is in-cycle and does NOT replace the final cross-cutting `coderabbit review --agent` pass — that runs once over the full diff after the last commit.

## Common Mistakes (TDD-specific)

| Mistake | Fix |
|---|---|
| Writing implementation before test in a cycle | Test comes first. Always. Reorder the cycle. |
| Test that can't actually fail | If the test would pass without your implementation, it tests nothing. Write a test that exercises new behavior. |
| Cycle tests multiple behaviors | Split into separate cycles. One assertion focus per cycle. |
| No verify commands | Every RED and GREEN needs a runnable command with expected output |
| GREEN implementation is over-engineered | Write the dumbest code that passes. Refactor later. |
| Skipping commit between cycles | Each cycle = one commit. This is the checkpoint. |
| Using mocks without user approval | No mocks unless the user explicitly says so. Check if the project uses request recording (VCR, OHHTTPStubs, etc.) instead. Ask during Phase 3 if unsure. |
| Per-cycle test verification treated as a substitute for final CodeRabbit review | They're complementary. Cycles verify behavior; the final `coderabbit review --agent` pass catches cross-cutting issues (security, perf, anti-patterns) the per-test asserts can't see. |
| Audit prompt missing TDD-specific checks | Append `audit-prompt-tdd-additions.md` to the base prompt before invoking the audit on a TDD plan. |

## Self-Containment Test (TDD addition)

In addition to the universal self-containment test in SKILL.md, verify:

- Does each cycle include the exact test command to run?
- Does each RED step include the expected failure message?
- Could the executing session run each cycle mechanically without judgment calls?
- Are test file paths and conventions consistent with what exploration found?
- Did Phase 4.5 audit run, or was it explicitly skipped (with a note in Risks)?
- Does the final Verification section call out `coderabbit review --agent` over the cumulative diff after all cycles?
