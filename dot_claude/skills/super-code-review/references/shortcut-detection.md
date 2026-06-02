# Shortcut Detection — Extended Catalog

Shared reference between `shortcut-intent-reviewer` and the orchestrator. The agent file lists the core patterns; this file has language-specific traps and harder cases.

## Comment-marker patterns

Standard markers — flag when added/moved by the diff:

```
TODO  FIXME  HACK  XXX  BUG  KLUDGE  OPTIMIZE  NOTE-TO-SELF
nocheckin  DNM  "DO NOT MERGE"  WIP  TEMPORARY  REMOVE-BEFORE-MERGE
```

### Attribution rule (Alex's repos)

Per global CLAUDE.md: TODOs must include attribution: `TODO(alexwu):`. Same for FIXME. Flag any unattributed TODO/FIXME in his repos.

```
# Detection
rg -n '\b(TODO|FIXME)([^(]|$)' <diff>      # TODO not immediately followed by (
```

Other repos may have their own conventions (e.g., `TODO(github-username):`) — check the repo's CLAUDE.md before flagging.

## Error-swallowing patterns by language

### Swift

```swift
// BAD — try? on a previously-thrown call, silently discards error
let user = try? decoder.decode(User.self, from: data)
// (was: try decoder.decode(...) — visible in the diff as a change)

// BAD — empty catch
do {
    try save()
} catch {
    // silently ignored
}

// BAD — log-and-continue
do {
    try save()
} catch {
    print("save failed: \(error)")   // no re-throw, no surface
}

// BAD — @unchecked Sendable
extension MyClass: @unchecked Sendable { }   // suspicious unless justified
```

Use `ast-grep` for the `catch { }` empty-body match — text grep misses multi-line bodies.

### Rust

```rust
// BAD — discarding Result
let _ = some_call();                       // intentional discard, but flag for review

// BAD — unwrap_or_default swallowing
let value = risky_op().unwrap_or_default(); // hides real failures

// BAD — match _ => {}
match result {
    Ok(v) => use(v),
    Err(_) => {},                          // empty error branch
}
```

### TS / JS

```typescript
// BAD — empty catch
try {
    await save();
} catch (e) {
    // nothing
}

// BAD — .catch swallow
fetchUser().catch(() => {});               // discards error silently

// BAD — ts-ignore without justification
// @ts-ignore
const x: Foo = bar;                        // @ts-expect-error requires reason comment per project rules
```

### Python

```python
# BAD — bare except
try:
    do_thing()
except:                                    # catches BaseException too
    pass

# BAD — broad except with pass
try:
    do_thing()
except Exception:
    pass

# BAD — log-and-continue
try:
    do_thing()
except Exception as e:
    print(e)                               # no raise, no escalation
```

### Nim

```nim
# BAD — empty except
try:
    doThing()
except:
    discard

# BAD — discard on a Result-like return
discard riskyOp()
```

## Bypass / safety-check escape patterns

These are usually shortcuts to silence a problem rather than fix it. Flag every occurrence added by the diff:

| Pattern | Why it's a shortcut |
|---|---|
| `git commit --no-verify` | Skips pre-commit hooks; investigate why |
| `--no-gpg-sign` | Skips commit signing; investigate why |
| `npm install --force` | Forces deps despite resolution conflicts |
| `pip install --no-deps` | Skips transitive dep resolution |
| `// eslint-disable-line` (no rule) | Disables all rules on a line |
| `// eslint-disable-next-line` (no rule) | Same |
| `# noqa` (no code) | Disables all Python lint rules |
| `# type: ignore` (no code) | Silences all mypy on the line |
| `@ts-ignore` | Silences TS error; prefer `@ts-expect-error` + reason |
| `unsafe { }` in Rust safe contexts | Sometimes necessary, often not — flag for review |
| `--allow-dirty`, `--skip-tests`, `--no-validate` flags in scripts | Self-explanatory |

If the line has an explanatory comment justifying the bypass, demote severity from "blocker" to "suggestion" — but still surface it.

## Commented-out code

> 2 lines of commented code is usually one of: dead weight, a pivot the author forgot to remove, or "I might need this back." All three are worth flagging.

```bash
# Detection — naive text grep is fine for this, real false positives are rare
rg -n '^[+]\s*(//|#|--).*\b(if|for|while|return|let|var|func|def|fn|impl)\b' <diff>
```

Filter: skip when the comment line starts with a doc-comment marker (`///`, `/**`, `#!`, `"""`).

## Stub-return / placeholder patterns

```
return true;       // TODO actual logic
return null;       // TODO
unimplemented!()   // Rust
todo!()            // Rust
fatalError("TODO") // Swift
throw new Error("not implemented")
raise NotImplementedError
panic!("not implemented")
```

If the function signature is non-trivial and the body is one of these, flag as a stub return.

## Scope-drift heuristics

For each substantive change in the diff, ask:

1. **Does the change touch a file directory the intent context mentions?** If not, suspicious.
2. **Is the change in the same module/feature as the stated goal?** Cross-feature changes in a "fix bug X" PR are drift.
3. **Does the diff include rename/restructure not mentioned in the intent?** Drive-by refactor.
4. **Is there an additive new feature in a "fix Y" PR?** Scope expansion.
5. **Is there a behavior change not mentioned in the intent?** Undisclosed change.

If the intent context is empty or vague (e.g., commit message `"wip"`, PR body `"see issue"` with no issue link), skip drift detection — there's no signal to compare against. Surface that gap to the user in the output instead.

## Anti-patterns that are NOT shortcuts

These look like shortcuts but are legitimate:

- `// TODO(alexwu): handle <case> — tracked in #123` — attributed and tracked
- `// Intentionally suppressed — see RFC-42` — justified with a doc reference
- `try? doSomething()` when the function's contract is "best-effort and may fail silently"
- `_ = result` when the caller genuinely doesn't care about the value (e.g., `_ = collection.removeFirst()` for side effect)
- Bypass flags in CI scripts where the repo has documented why
- Stub returns in mocks/test doubles (these aren't shortcuts, they're fixtures)

When in doubt, demote to "suggestion" severity and let the user judge.
