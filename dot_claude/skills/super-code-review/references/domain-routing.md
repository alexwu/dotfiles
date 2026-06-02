# Domain Routing

How to detect what's in the repo and which specialized skill / auditor agents to add to the Phase 2 fan-out.

## Detection (run in parallel during Phase 1)

```bash
# All checked in parallel — one Glob/Bash per row, single message
test -d "*.xcodeproj" -o -d "*.xcworkspace" -o -f "Package.swift"        # iOS / macOS / Swift Package
test -f "Cargo.toml"                                                       # Rust
fd -t f -e nim -e nimble . --max-results 1                                 # Nim
test -f "tsconfig.json" -o -f "package.json"                              # TS / JS
test -f "pyproject.toml" -o -f "setup.py" -o -f "requirements.txt"        # Python
test -f "go.mod"                                                           # Go
test -f "build.gradle*"                                                    # Kotlin / Java / Gradle
test -f "*.csproj" -o -f "*.sln"                                           # C# / .NET
test -f "Gemfile"                                                          # Ruby
```

Then refine: read a handful of changed files to detect frameworks within the language (SwiftUI vs UIKit, React vs Vue, etc.).

## Routing table — iOS / Swift

When iOS Swift is detected, add the matching axiom auditors to Phase 2:

| Diff signal | Add auditor |
|---|---|
| SwiftUI imports / `View` conformances changed | `axiom:swiftui-architecture-auditor`, `axiom:swiftui-layout-auditor`, `axiom:swiftui-nav-auditor` (route by what changed — architecture, layout, navigation) |
| `async`, `await`, `actor`, `Task`, `@MainActor` touched | `axiom:concurrency-auditor` |
| `@Model`, `ModelContainer`, `ModelContext` touched | `axiom:swiftdata-auditor` |
| `NSManagedObject`, `NSPersistentContainer`, Core Data xcdatamodel touched | `axiom:core-data-auditor` |
| `XCTest` / `Testing` test files changed | `axiom:testing-auditor` (in addition to our `test-thoroughness-reviewer`) |
| `AVCapture*`, photo/video capture | `axiom:camera-auditor` |
| `LanguageModelSession`, `@Generable`, Foundation Models | `axiom:foundation-models-auditor` |
| `Codable`, `JSONEncoder`/`JSONDecoder`, `JSONSerialization` | `axiom:codable-auditor` |
| `Timer`, `CADisplayLink`, polling loops | `axiom:energy-auditor`, `axiom:memory-auditor` |
| `CKContainer`, CloudKit, `FileManager` for ubiquitous container | `axiom:icloud-auditor` |
| `StoreKit` / `Transaction` / `Product` | `axiom:iap-auditor` |
| `NavigationStack`, `NavigationSplitView`, `NavigationPath` | `axiom:swiftui-nav-auditor` |
| `Migration` / `VersionedSchema` in SwiftData | `axiom:swiftdata-auditor` |
| Liquid Glass / `glassEffect` / iOS 26 UI | `axiom:liquid-glass-auditor` |
| Accessibility identifier / `.accessibilityLabel` changes | `axiom:accessibility-auditor` |
| `SKNode`, SpriteKit | `axiom:spritekit-auditor` |
| `URLSession`, networking | `axiom:networking-auditor` |
| `UITextView`, `NSTextView`, `TextKit` | `axiom:textkit-auditor` |

If the diff touches multiple of these, invoke them all in parallel. Each runs independently and the orchestrator merges findings.

Also: when SwiftUI patterns appear, invoke `pfw-*` skills via the bug-reviewer's `Read` of its skill list — they're guidance skills, not auditor agents. Specifically:
- `pfw-modern-swiftui` for naming/binding/init correctness
- `pfw-observable-models` for ViewModel-vs-@Observable boundary
- `pfw-composable-architecture` if TCA is in use (detect `import ComposableArchitecture`)
- `pfw-structured-queries` / `pfw-sqlite-data` if `import StructuredQueries` / `import SQLiteData`
- `pfw-dependencies` for testability of dependency injection
- `pfw-snapshot-testing` / `pfw-macro-testing` for test review enrichment

These are skill invocations (via the `Skill` tool), not agent spawns. The orchestrator can either pass skill hints into the relevant reviewer's prompt, or invoke them itself and inject the resulting guidance.

## Routing table — Rust

| Diff signal | Add |
|---|---|
| `unsafe` blocks added | Heightened bug-reviewer prompt: focus on memory safety |
| `async fn` / `tokio` / `async-std` | Heightened bug-reviewer prompt: focus on send/sync/lifetimes |
| `#[cfg(test)]` blocks | Pass through `test-thoroughness-reviewer` |

No dedicated auditor agents for Rust yet — the generic reviewers cover it with prompt enrichment.

## Routing table — Nim

| Diff signal | Add |
|---|---|
| `.nim` / `.nims` / `.nimble` files | Reviewer prompts get NEP-1 reminder (style guide) + `nph` formatting expectation |
| `cligen` imports | Bug-reviewer prompt notes cligen `dispatchMulti` patterns |
| Hooks (`scripts/claude/*.nim`) | Cross-reference `claude-scripts.md` rules |

Invoke the `writing-nim-code` skill in the bug-reviewer prompt as a guidance reference (not spawn).

## Routing table — TS / JS

| Diff signal | Add |
|---|---|
| React component files | Reviewer prompts get React rules-of-hooks reminder |
| `useEffect` / `useMemo` / `useCallback` | Bug-reviewer focus on dep-array correctness |
| TypeScript with `any` / `as` casts | Shortcut-intent-reviewer flags the casts |

No dedicated auditors. Generic reviewers + prompt enrichment.

## Routing table — Python

| Diff signal | Add |
|---|---|
| `async def` / `asyncio` | Bug-reviewer focus on `await` correctness + context managers |
| `try: ... except: pass` | Shortcut-intent-reviewer (always flagged regardless of language) |
| `pyproject.toml` or `requirements.txt` changes | Reviewer prompts note dependency review concern |

## When the language isn't recognized

Run the four generic reviewers + Codex with no domain enrichment. The reviewers' default prompts are language-agnostic and will still find the universal bug classes (off-by-one, null deref equivalents, error swallowing, scope drift).

## How to invoke an auditor

```python
# Pseudocode for the orchestrator's spawn step
Agent(
  subagent_type="axiom:swiftui-architecture-auditor",
  prompt=<domain-auditor template from agent-prompts.md, constrained to changed files>
)
```

Use the auditor's subagent_type (the full plugin:name form as it appears in the available-agents list). If the auditor isn't installed, the Agent spawn will fail — catch that and skip silently with a note in the output that the auditor was expected but unavailable.

## Update path

If the user adds a new domain-specific skill or auditor, add a row to this table. The orchestrator reads this file to know what to spawn — keep it in sync with what's actually installed.
