# macOS Tools

Nim CLIs in `scripts/macos/` (source-only, ignored by chezmoi; binaries compile to
`~/.local/bin/` via `run_onchange_build-scripts.sh.tmpl`).

## `electron-apps`

`scripts/macos/electron_apps.nim` (binary `electron-apps`) — lists installed
Electron apps, largest bundle first. `electron-apps [--json] [ROOT ...]`. Roots
default to `/Applications`, `~/Applications`, `/System/Applications`; descends 2
levels past a root (catches `/Applications/Datacolor/Spyder/Spyder.app`) and never
descends into a bundle, since an Electron app's own helper processes are `.app`s.
Table to stdout, counts + caveats to stderr, so `--json | jaq …` stays clean.

### Detection — both signals required

1. **A Chromium framework:** some `Contents/Frameworks/*.framework` containing
   `Libraries/libEGL.dylib`.
2. **A JS payload:** `Resources/app*.asar`, an unpacked `Resources/app`, or the
   `ElectronAsarIntegrity` key in `Contents/Info.plist`.

Every single-signal heuristic was tried and **fails** on this machine's 129 apps:

| Naive check | Breaks on |
|---|---|
| framework named `Electron Framework.framework` | **Codex.app** — Electron allows renaming; it ships `Codex Framework.framework`, bundle id `com.openai.codex.framework` |
| `libEGL.dylib` in a framework | **Chrome, Brave, Arc, Dia, Helium** — real Chromium browsers, not Electron |
| `Resources/app.asar` exists | **VS Code, LM Studio** — no asar at all, just an unpacked `Resources/app` |
| `ElectronAsarIntegrity` in `Info.plist` | **Bazecor** — older Electron, predates the integrity manifest |
| `app.asar` exactly | **Slack** also ships `app-arm64.asar` / `app-x64.asar` |

The conjunction caught all 12 with zero false positives. Because the framework
gate excludes the browsers, the payload gate can stay generous.

### Version reporting is deliberately hedged
The version shown is the framework's `CFBundleVersion`, read with `plutil -extract
… raw -o -`. That IS the Electron version only when the framework's bundle id is
the canonical `com.github.Electron.framework`. A renamed framework carries the
**vendor's own** number (Codex reports `7871.101`), so it prints as `?` with a
footnote, and `--json` sets `electronVersion: null` while still exposing
`frameworkVersion` / `frameworkBundleId`. Don't "fix" this by trusting the number.

### Homebrew needs no special handling
`brew install --cask` **moves** the bundle into `/Applications` as a real directory
and leaves a symlink behind at `/opt/homebrew/Caskroom/<cask>/<version>/Foo.app`
pointing back to it. So the default roots already cover every cask; adding
Caskroom as a root would only double-count. (Verified: Figma/Notion/LM Studio
Caskroom entries are `Symbolic Link -> /Applications/….app`.)

### Gotchas
- `/Applications/Utilities` is empty on modern macOS — the real utilities live at
  `/System/Applications/Utilities`. A zero-count scan of the former is correct.
- Nim's `strformat` renders `{x:.0f}` with a **trailing `.`** (`"824."`). `human()`
  rounds to an `int` instead of formatting with zero decimals.
- Sizes come from `du -sk` on the **realpath-resolved** bundle (one spawn per
  confirmed Electron app only, ~12 — the non-Electron majority never gets stat'd
  beyond the framework check). A bundle can be a symlink (`/Applications/Safari.app`
  is; so is every Caskroom entry) and plain `du -sk` would score it 0. Do **not**
  reach for `du -skL` instead: it also follows the `Versions/Current` links inside
  a framework and double-counts — Slack reads 1.5 GB rather than 536 MB.
