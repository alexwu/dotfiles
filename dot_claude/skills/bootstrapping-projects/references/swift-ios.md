# Swift / iOS project bootstrap

> ⚠️ **WORK IN PROGRESS — do not treat as settled.** Alex is unhappy with the
> current state of his Swift repos *because* there was no bootstrap discipline,
> so this reference is being designed *with* him rather than mined from existing
> code. The architecture default and the exact dependency picks are **pending a
> focused session**. Until then: load the deep skills below and ask Alex before
> committing to an architecture or a `pfw-*` dependency.

## Deep skills to load (these own the idioms)

- **`building-swiftui-views`** — vanilla SwiftUI, `@Observable` models, **no
  ViewModels**, iOS 26 / Liquid Glass.
- **`pfw-*`** — the Point-Free ecosystem, used *selectively* (Alex uses some of
  these, not all): `pfw-composable-architecture` (TCA), `pfw-dependencies`,
  `pfw-sqlite-data`, `pfw-sharing`, `pfw-swift-navigation`, `pfw-snapshot-testing`,
  `pfw-testing`, `pfw-spm`, etc.

## What's already decided

- **Layout:** modular SPM — a thin app target over feature/domain packages in
  `Packages/` (the `lulu-app` `Packages/*Kit` shape is the good part to emulate).
  Defer SPM specifics to `pfw-spm`.
- **Max-file-length:** Swift is the one stack with a *native* file cap —
  **SwiftLint `file_length`** in `.swiftlint.yml`:

  ```yaml
  file_length:
    warning: 400
    error: 500
  ```

  `swiftlint lint --strict` exits non-zero on any violation. The shared `wc -l`
  hook still works as a uniform fallback, but SwiftLint is the native choice here
  and brings many other anti-sprawl rules (type body length, cyclomatic
  complexity, function length) for free.

## Open questions for the session with Alex

1. **Default architecture** — "it depends." Get Alex's decision rule: when vanilla
   `@Observable` (per `building-swiftui-views`) vs when TCA (`pfw-*`).
2. **Which `pfw-*` libraries are defaults** vs which he avoids — he'll lay out
   likes/dislikes. Don't assume the whole suite.
3. **Format + lint stack** — `swift-format` (Apple) vs SwiftFormat (Nick Lockwood)
   vs SwiftLint-only, and how they compose on the `prek` gate.
4. **Toolchain/version pinning** for Swift + the Xcode/SPM split.

Once settled, fill this out to match the shape of `references/rust.md`
(layout → toolchain → format → caps → test/TDD → prek gate → justfile → deps).
