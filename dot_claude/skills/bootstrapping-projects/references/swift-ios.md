# Swift / iOS project bootstrap

Grounded in **`aerospace-manager`** — the freshest, most intentional Swift setup
(and the repo that prompted this skill). Defer Swift *idioms* to the deep skills;
this reference owns layout + the gate + dependency defaults.

## Deep skills to load (these own the idioms)

- **`building-swiftui-views`** — vanilla SwiftUI, `@Observable` models, **no
  ViewModels**, iOS 26 / Liquid Glass.
- **`pfw-*`** — the Point-Free libraries, used **à la carte** (see Dependencies).
  Relevant ones: `pfw-dependencies`, `pfw-sharing`, `pfw-sqlite-data`,
  `pfw-structured-queries`, `pfw-identified-collections`, `pfw-case-paths`,
  `pfw-snapshot-testing`, `pfw-spm`, `pfw-swift-navigation`, `pfw-testing`.

## Architecture default

**Vanilla `@Observable` + à-la-carte Point-Free.** Use `@Observable` models (per
`building-swiftui-views`) plus the individual Point-Free *libraries* you need —
**NOT** the TCA framework (`swift-composable-architecture`) and **not**
`swift-navigation` by default. This matches real usage: `lulu-app` pulls 14
Point-Free libraries but neither TCA nor swift-navigation; `aerospace-manager`
(a tool) uses zero Point-Free deps at all.

## Layout — modular SPM with layered targets

One `Package.swift`, many small targets under `Sources/`, one test target each
under `Tests/`. Enforce a **dependency hierarchy**: pure-value model target with
*zero* dependencies at the bottom; feature/domain "Kit" targets depend on Models;
UI depends on Models only (never on the domain Kits); executables compose
everything at the top.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "my-project",
  platforms: [.macOS("26.0")],          // pin the floor explicitly
  products: [
    .executable(name: "my-projectd", targets: ["my-projectd"]),
    .library(name: "MyProjectModels", targets: ["MyProjectModels"]),
  ],
  targets: [
    .target(name: "MyProjectModels"),                                  // zero deps — shared vocabulary
    .target(name: "MyProjectKit", dependencies: ["MyProjectModels"]),  // domain logic
    .target(name: "OverlayUI", dependencies: ["MyProjectModels"]),     // UI → Models only
    .executableTarget(name: "my-projectd",
      dependencies: ["MyProjectModels", "MyProjectKit", "OverlayUI"]),
    .testTarget(name: "MyProjectModelsTests", dependencies: ["MyProjectModels"]),
    .testTarget(name: "MyProjectKitTests", dependencies: ["MyProjectKit", "MyProjectModels"]),
  ],
  swiftLanguageModes: [.v6]              // Swift 6 strict concurrency
)
```

For a **bigger app**, the same idea scales to a thin app target over feature
packages in a `Packages/` directory (the `lulu-app` `Packages/*Kit` shape); defer
SPM specifics to `pfw-spm`.

## Toolchain

- **`swift-tools-version: 6.0`** + **`swiftLanguageModes: [.v6]`** — Swift 6 strict
  concurrency on from day one.
- Pin the platform floor explicitly (`.macOS("26.0")` / the iOS floor).
- No separate `.swift-version` — the tools-version + language mode are the pin.

## The quality gate — four tools, clear lanes

The headline pattern: **each tool owns one lane and they're configured not to
fight.** SwiftLint's body-length + complexity caps ARE the anti-sprawl mechanism
here — Swift needs **no `wc -l` hook**.

### 1. Format — Apple `swift-format` (`.swift-format`)

```json
{
  "version": 1,
  "lineLength": 120,
  "indentation": { "spaces": 2 },
  "lineBreakBeforeEachArgument": true,
  "indentConditionalCompilationBlocks": false,
  "prioritizeKeepingFunctionOutputTogether": true,
  "rules": {
    "OrderedImports": true,
    "AlwaysUseLowerCamelCase": false,
    "UseSynthesizedInitializer": false
  }
}
```

`swift-format` has **no `--exclude`** — feed it an explicit file list
(`fd -e swift . Sources Tests -0 | xargs -0 swift-format …`).

### 2. Lint — SwiftLint (`.swiftlint.yml`)

**SwiftLint owns style + complexity; swift-format owns whitespace/layout.**
Disable the SwiftLint rules that would fight the formatter, then turn on the
anti-monolith caps — the whole reason SwiftLint is here:

```yaml
# swift-format owns whitespace/layout; disable the rules that would fight it.
disabled_rules:
  - trailing_whitespace
  - vertical_whitespace
  - opening_brace
  - line_length        # swift-format enforces the 120-col limit

opt_in_rules:
  - empty_count
  - first_where
  - last_where
  - explicit_init
  - force_unwrapping

excluded: [.build, build]

# Anti-monolith guardrails — the whole point.
file_length:          { warning: 400, error: 600, ignore_comment_only_lines: true }
type_body_length:     { warning: 250, error: 400 }
function_body_length: { warning: 50,  error: 80 }
cyclomatic_complexity:{ warning: 10,  error: 20 }
type_name:            { min_length: 3 }
```

Run `swiftlint lint --strict` (warnings fail).

### 3. Dead code — Periphery (`.periphery.yml`)

```yaml
# SPM auto-detected. retain_public treats public decls as entry points while the
# API surface is still settling; drop it once stable to catch dead public API too.
retain_public: true
```

`periphery scan --strict`. It's slow (builds an index) — run it on **pre-push**,
not pre-commit.

### 4. Test — Swift Testing (the modern framework, not XCTest)

`import Testing` with `@Test` / `#expect` / `@Suite`. **No XCTest.** TDD: Red →
verify-red → minimal green → commit at GREEN. One test target per library.

```swift
import Testing
@testable import MyProjectModels

@Test func emptySnapshotHasNoMonitors() {
  #expect(Snapshot().monitors.isEmpty)
}
```

## Pre-commit gate — `prek.toml` (note the stage split)

Fast checks on **pre-commit**; slow checks (Periphery index, full test) on
**pre-push**:

```toml
[[repos]]
repo = "local"

[[repos.hooks]]
id = "swift-format-lint"
entry = "swift-format lint --strict --configuration .swift-format"
language = "system"
files = '\.swift$'
stages = ["pre-commit"]

[[repos.hooks]]
id = "swiftlint"
entry = "swiftlint lint --strict --quiet"
language = "system"
files = '\.swift$'
stages = ["pre-commit"]

[[repos.hooks]]
id = "periphery"
entry = "periphery scan --strict"
language = "system"
pass_filenames = false
always_run = true
stages = ["pre-push"]

[[repos.hooks]]
id = "swift-test"
entry = "swift test"
language = "system"
pass_filenames = false
always_run = true
stages = ["pre-push"]
```

Install with `prek install --hook-type pre-commit --hook-type pre-push` (see the
`prek` skill).

## `justfile` spine

Agent-aware build output (machine-parseable for Claude/Codex, pretty for humans);
`check` is the full local gate:

```just
agent_env := env("CLAUDECODE", "") + env("CODEX_SANDBOX", "")
swift_pipe := if agent_env != "" { "xcsift -f toon" } else { "xcbeautify" }

fmt:
    fd -e swift . Sources Tests -0 | xargs -0 swift-format format --in-place --configuration .swift-format
fmt-check:
    fd -e swift . Sources Tests -0 | xargs -0 swift-format lint --strict --configuration .swift-format
lint:
    swiftlint lint --strict
test *args:
    swift test {{ args }} 2>&1 | {{ swift_pipe }}
dead-code:
    periphery scan --strict
check: fmt-check lint build test dead-code
```

## Dependency defaults (verify with `find-docs` before adopting)

| Need | Reach for | Note |
|------|-----------|------|
| CLI args | `swift-argument-parser` | |
| Persistence | **`sqlite-data`** (Point-Free) | a wrapper over GRDB — **prefer it**; reach for `GRDB.swift` directly only when sqlite-data genuinely can't cover it |
| Dependency injection | **judgement call — `Factory` and `swift-dependencies` are both valid** | note `swift-dependencies` is often *already in the graph* as a transitive requirement of other Point-Free libraries |
| State sharing | `swift-sharing` | |
| Collections w/ stable IDs | `swift-identified-collections` | |
| Enum ergonomics | `swift-case-paths` | |
| Debug dumps | `swift-custom-dump` | |
| Snapshot tests | `swift-snapshot-testing` | |

Pull Point-Free libraries **individually as needed** — don't add the whole suite.
A pure tool/CLI may use **zero** of them (aerospace-manager does).
