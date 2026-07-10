## electron-apps — list the Electron apps installed on this Mac, biggest first.
##
## Usage: electron-apps [--json] [ROOT ...]
##   ROOT     directories to scan (default: /Applications, ~/Applications,
##            /System/Applications). Descends 2 levels past a root so nested
##            trees like /Applications/Datacolor/Spyder/Spyder.app are seen,
##            and never descends INTO a bundle (helper .apps aren't apps).
##   --json   emit an array of records instead of a table.
##
## DETECTION — an app is Electron iff it has BOTH:
##
##   1. a Chromium framework: some `Contents/Frameworks/*.framework` holding
##      `Libraries/libEGL.dylib`. Matching the framework's *name* fails — Electron
##      lets vendors rename it (Codex ships `Codex Framework.framework`, bundle id
##      `com.openai.codex.framework`), so match on the GL shim instead.
##
##   2. a JS payload: `Resources/app*.asar` (Slack also ships `app-arm64.asar`),
##      an unpacked `Resources/app` (VS Code, LM Studio ship no asar at all), or
##      the `ElectronAsarIntegrity` manifest Electron injects into `Info.plist`.
##
## Either signal alone lies. (1) alone matches real Chromium browsers — Chrome,
## Brave, Arc, Dia, Helium. (2) alone would trust a directory name. Together they
## caught all 12 Electron apps on the reference machine with no false positives.
##
## The reported version is the framework's CFBundleVersion, which IS the Electron
## version only for the canonical `com.github.Electron.framework`. A renamed
## framework carries the vendor's own number, so it's shown as `?` with a
## footnote rather than passed off as an Electron release.

import std/[algorithm, json, math, os, osproc, sequtils, streams, strformat, strutils]

const
  ElectronFrameworkId = "com.github.Electron.framework"
  ChromiumMarker = "Libraries/libEGL.dylib"
  IntegrityKey = "ElectronAsarIntegrity"
  MaxDepth = 2 # non-bundle dirs to descend past each root

type ElectronApp = object
  path: string
  name: string
  framework: string ## bundle dir name, e.g. "Electron Framework.framework"
  frameworkId: string
  frameworkVersion: string
  sizeKb: int64

func isCanonical(a: ElectronApp): bool =
  a.frameworkId == ElectronFrameworkId

proc sh(cmd: string, args: openArray[string]): tuple[code: int, outp: string] =
  ## Run, returning (exit code, trimmed stdout). Soft — never raises/quits.
  try:
    let p = startProcess(cmd, args = args, options = {poUsePath})
    p.inputStream.close()
    let outp = p.outputStream.readAll()
    discard p.errorStream.readAll()
    let code = p.waitForExit()
    p.close()
    (code, outp.strip())
  except CatchableError:
    (1, "")

proc plistString(plist, key: string): string =
  ## One key out of a (usually binary) plist, or "" if absent/unreadable.
  let (code, outp) = sh("plutil", ["-extract", key, "raw", "-o", "-", plist])
  if code == 0: outp else: ""

proc chromiumFramework(app: string): string =
  ## Path of the app's Chromium framework bundle, or "" if it has none.
  let fwDir = app / "Contents" / "Frameworks"
  if not dirExists(fwDir):
    return ""
  try:
    for kind, path in walkDir(fwDir):
      if kind in {pcDir, pcLinkToDir} and path.endsWith(".framework") and
          fileExists(path / ChromiumMarker):
        return path
  except OSError:
    discard
  ""

proc hasJsPayload(app: string): bool =
  ## The signal that separates Electron from a plain Chromium browser.
  let res = app / "Contents" / "Resources"
  if dirExists(res / "app"):
    return true
  if dirExists(res):
    try:
      for kind, path in walkDir(res):
        let base = path.extractFilename
        if kind == pcFile and base.startsWith("app") and base.endsWith(".asar"):
          return true
    except OSError:
      discard
  try:
    IntegrityKey in readFile(app / "Contents" / "Info.plist")
  except CatchableError:
    false

proc bundleSizeKb(app: string): int64 =
  # A bundle can itself be a symlink (/Applications/Safari.app, and every
  # Caskroom entry points back into /Applications), and `du -sk` would measure
  # the link as 0. Resolve the top level first — NOT `du -skL`, which also
  # follows the Versions/Current links *inside* a framework and double-counts
  # (Slack reads 1.5 GB instead of 536 MB).
  let real =
    try:
      expandFilename(app)
    except OSError:
      app
  let (code, outp) = sh("du", ["-sk", real])
  if code != 0:
    return 0
  try:
    parseBiggestInt(outp.split('\t')[0].strip())
  except ValueError:
    0

proc collectApps(dir: string, depth: int, acc: var seq[string]) =
  ## Every .app under `dir`, never descending into a bundle — the helper
  ## processes inside an Electron app are .apps too, and aren't installed apps.
  if not dirExists(dir):
    return
  try:
    for kind, path in walkDir(dir):
      if path.endsWith(".app"):
        if kind in {pcDir, pcLinkToDir}:
          acc.add path
      elif kind == pcDir and depth > 0:
        collectApps(path, depth - 1, acc)
  except OSError:
    discard

func human(kb: int64): string =
  # NOTE(alexwu): `{x:.0f}` renders a trailing "." in Nim's strformat — round to
  # an int instead of formatting with zero decimals.
  if kb >= 1024 * 1024:
    &"{kb.float / (1024.0 * 1024.0):.1f} GB"
  elif kb >= 1024:
    &"{(kb.float / 1024.0).round.int} MB"
  else:
    &"{kb} KB"

proc inspect(path: string): (bool, ElectronApp) =
  let fw = chromiumFramework(path)
  if fw.len == 0 or not hasJsPayload(path):
    return (false, ElectronApp())
  let plist = fw / "Resources" / "Info.plist"
  (
    true,
    ElectronApp(
      path: path,
      name: path.extractFilename.changeFileExt(""),
      framework: fw.extractFilename,
      frameworkId: plistString(plist, "CFBundleIdentifier"),
      frameworkVersion: plistString(plist, "CFBundleVersion"),
      sizeKb: bundleSizeKb(path),
    ),
  )

proc emitJson(apps: openArray[ElectronApp]) =
  var arr = newJArray()
  for a in apps:
    arr.add %*{
      "name": a.name,
      "path": a.path,
      "sizeKb": a.sizeKb,
      "sizeHuman": human(a.sizeKb),
      "framework": a.framework,
      "frameworkBundleId": a.frameworkId,
      "frameworkVersion": a.frameworkVersion,
      "electronVersion":
        if a.isCanonical:
          %a.frameworkVersion
        else:
          newJNull(),
    }
  echo arr.pretty

proc emitTable(apps: openArray[ElectronApp]) =
  var nameW = 4
  for a in apps:
    nameW = max(nameW, a.name.len)
  echo &"""{"NAME".alignLeft(nameW)}  {"ELECTRON".alignLeft(10)}  SIZE"""
  for a in apps:
    let ver = if a.isCanonical: a.frameworkVersion else: "?"
    let note =
      if a.isCanonical:
        ""
      else:
        &"   ← {a.framework} ({a.frameworkId})"
    echo &"{a.name.alignLeft(nameW)}  {ver.alignLeft(10)}  {human(a.sizeKb).align(8)}{note}"

proc main(json = false, roots: seq[string]) =
  let searchRoots =
    if roots.len > 0:
      roots
    else:
      @["/Applications", getHomeDir() / "Applications", "/System/Applications"]

  var candidates: seq[string]
  for r in searchRoots:
    collectApps(expandTilde(r), MaxDepth, candidates)

  var apps: seq[ElectronApp]
  for path in candidates:
    let (isElectron, app) = inspect(path)
    if isElectron:
      apps.add app
  apps.sort(
    proc(a, b: ElectronApp): int =
      cmp(b.sizeKb, a.sizeKb)
  )

  if json:
    emitJson(apps)
  else:
    emitTable(apps)

  var total: int64
  for a in apps:
    total += a.sizeKb
  stderr.writeLine(
    &"electron-apps: {apps.len} Electron apps ({human(total)}) of " &
      &"{candidates.len} scanned"
  )
  if apps.anyIt(not it.isCanonical):
    stderr.writeLine(
      "electron-apps: `?` = framework renamed by the vendor, so its " &
        "CFBundleVersion is not an Electron release number"
    )

when isMainModule:
  import cligen

  dispatch(
    main,
    cmdName = "electron-apps",
    usage = "$command [--json] [ROOT ...]\n\nOptions:\n$options",
    help = {
      "json": "emit records instead of a table",
      "roots":
        "directories to scan (default: /Applications, ~/Applications, /System/Applications)",
    },
  )
