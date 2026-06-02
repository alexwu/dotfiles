## image-sort — classify a Downloads image as lulu / screenshot / meme /
## wallpaper / other via `llm-local` vision, then rename + route it into a
## sorted folder tree.
## Designed for invocation from a Hazel rule (or run manually, per file).
##
## Usage: image-sort [--dry-run|-n] [-m|--model <id>] <input-file> [root]
##
## - --dry-run/-n: classify and print where the file WOULD go; move nothing.
## - <input-file>: HEIC, HEIF, JPG, JPEG, PNG, WEBP, AVIF, SVG, GIF, or a short
##                 video (MP4/MOV/M4V/WEBM/MKV). Any other extension is skipped
##                 (exit 0, file untouched) — never a hard error.
## - [root]:       destination root for the sorted tree. Defaults to
##                 ~/Downloads/Images. Change this ONE path to relocate the
##                 whole library later (e.g. into BombeeCloud).
## - -m, --model:  llama-swap model id passed to `llm-local -m` (positional model
##                 arg removed — pass `-m <id>` anywhere in the args). Defaults to
##                 gemma-4-26B-A4B-it — stock MoE, 14/14 in the bake-off and ~2x
##                 faster than the 31B dense at identical accuracy. Kept always-on
##                 (resident → no cold-load swap, which once wedged a call ~10min).
##                 Under strict-schema decoding the censorship never fires (the
##                 grammar forces a category), so it labels NSFW correctly without
##                 refusing. NOT a heretic: abliteration only hurt classification
##                 here (the 26B heretic missed the B&W android the stock 26B gets
##                 right). gemma-4-31B-it stays in the workhorse group as the
##                 on-demand strongest-model fallback.
##
## A single `llm-local --schema image-sort --promptFile image-sort` call
## returns { category, style, nsfw, name }. Routing under <root>:
##
##   lulu       -> Lulu/<style>/<name>.png          (nsfw -> Lulu/<style>/nsfw/)
##   screenshot -> Screenshots/<name>.png
##   meme       -> Memes/<name>.png
##   wallpaper  -> Wallpapers/<name>.png            (nsfw -> Wallpapers/nsfw/)
##   other      -> Other/<original-filename>         (moved as-is, not renamed)
##
## Inputs are normalized to a working PNG for the vision call, by kind:
##   - png:            classified in place (no copy — already the target format)
##   - svg:            rasterized with `resvg` (pure-Rust, fast)
##   - animated gif /
##     short video:    a `gif-mosaic` contact sheet (evenly-sampled frames) so
##                     the model classifies off the whole animation, not frame 1
##   - other raster
##     (heic/jpg/…/avif/static gif): `sips`-converted
## Alongside the image the call also gets a text hint with the ORIGINAL format,
## file size, and pixel dimensions — so a rasterized .svg or an icon-sized asset
## isn't mistaken for a wallpaper. What actually lands in the library:
## a PNG / GIF / SVG / video keeps its ORIGINAL file (already the right format, or
## animation/vector/clip preserved — the working PNG was just a proxy), renamed to
## <name>.<ext>; only CONVERTED raster (heic/jpg/jpeg/webp/avif) lands as the new
## <name>.png with the original trashed; `other` is moved verbatim.
## Videos go through gif-mosaic WITHOUT --force, so its size/duration guard
## rejects a full-length movie — which is then skipped, not misfiled. Frame-count
## detection for gifs uses `magick`. All helpers resolve on PATH.
##
## WARNING(alexwu): if this is ever wired to a Hazel rule on ~/Downloads, scope
## the rule to the top level only — with <root> inside Downloads it would
## otherwise re-process its own Images/ subfolders in a loop. Moving <root>
## out of Downloads removes the hazard entirely.

import std/[os, osproc, streams, strutils, tempfiles]
import std/options
import json_serialization
import json_serialization/std/options as jsOptions

const
  defaultModel = "gemma-4-26B-A4B-it"
  defaultRootRel = "Downloads/Images" # relative to $HOME
  knownStyles = ["realistic", "anime", "cartoon"]
  videoExts = [".mp4", ".mov", ".m4v", ".webm", ".mkv"]
  imageExts = [
    ".heic", ".heif", ".jpg", ".jpeg", ".png", ".webp", ".avif", ".svg", ".gif", ".mp4",
    ".mov", ".m4v", ".webm", ".mkv",
  ]

type Classification = object
  ## Decoded `llm-local` structured output. Every field Option[T] so a
  ## malformed/short response surfaces as None at decode time rather than a
  ## silent zero-value (per the repo's json_serialization convention).
  category*: Option[string]
  style*: Option[string]
  nsfw*: Option[bool]
  name*: Option[string]

proc fail(msg: string) {.noreturn.} =
  stderr.writeLine "image-sort: " & msg
  quit(1)

proc skip(msg: string) {.noreturn.} =
  ## Exit 0 (success) without moving anything — so Hazel marks the file
  ## processed and logs no failure, leaving it untouched in place. Used for
  ## unsupported extensions and full-length videos the mosaic guard declines.
  ## (A `fail` here would surface as "Shell script failed" in Hazel and leave
  ## the file to be retried, which is the wrong signal for "not my job".)
  stderr.writeLine "image-sort: " & msg
  quit(0)

proc run(cmd: string, args: openArray[string]): string =
  ## Run `cmd` with `args` (no shell). Returns trimmed stdout.
  ## Closes the child's stdin immediately (EOF) so tools that read stdin when
  ## it isn't a TTY — `llm-local`, `xh` — see EOF and read nothing instead of
  ## blocking forever on a body that never arrives. Drains stderr separately so
  ## a chatty stderr can't fill its pipe and deadlock the child. `fail`s on
  ## non-zero exit.
  let p = startProcess(cmd, args = args, options = {poUsePath})
  # Qualify the Stream ops: json_serialization pulls in faststreams, whose
  # close/readAll otherwise collide with std/streams' here.
  streams.close(p.inputStream)
  let output = streams.readAll(p.outputStream)
  let errOutput = streams.readAll(p.errorStream)
  let exitCode = p.waitForExit()
  p.close()
  if exitCode != 0:
    let detail =
      if errOutput.strip().len > 0:
        errOutput.strip()
      else:
        output.strip()
    fail("`" & cmd & "` failed (exit " & $exitCode & "): " & detail)
  result = output.strip()

proc tryRun(cmd: string, args: openArray[string]): bool =
  ## Like `run`, but returns success/false instead of aborting on non-zero —
  ## for a call whose failure is an expected signal rather than an error (a
  ## full-length video tripping gif-mosaic's size/duration guard).
  let p = startProcess(cmd, args = args, options = {poUsePath})
  streams.close(p.inputStream)
  discard streams.readAll(p.outputStream)
  discard streams.readAll(p.errorStream)
  let exitCode = p.waitForExit()
  p.close()
  exitCode == 0

proc slugify(raw: string): string =
  ## Lowercase, drop a trailing `.png`, collapse runs of non-alnum to a single
  ## `-`, trim leading/trailing dashes.
  var lower = raw.toLowerAscii()
  if lower.endsWith(".png"):
    lower.setLen(lower.len - 4)
  result = newStringOfCap(lower.len)
  var prevDash = true
  for ch in lower:
    if ch in {'a' .. 'z', '0' .. '9'}:
      result.add ch
      prevDash = false
    elif not prevDash:
      result.add '-'
      prevDash = true
  if result.len > 0 and result[^1] == '-':
    result.setLen(result.len - 1)

proc uniquePath(dir, base, ext: string): string =
  ## dir/base.ext, suffixing -2, -3, ... until it doesn't collide.
  result = dir / (base & ext)
  var i = 2
  while fileExists(result):
    result = dir / (base & "-" & $i & ext)
    inc i

proc trashOrDelete(path: string) =
  let trashPath = findExe("trash")
  if trashPath.len > 0:
    discard run(trashPath, [path])
  else:
    removeFile(path)

proc gifFrames(path: string): int =
  ## Frame count via `magick identify` — 1 for a still, or on any failure
  ## (soft: a frame-count miss must never abort the sort). `magick identify`
  ## prints one line per frame, so the line count is the frame count.
  try:
    let p = startProcess("magick", args = ["identify", path], options = {poUsePath})
    streams.close(p.inputStream)
    let outp = streams.readAll(p.outputStream)
    discard streams.readAll(p.errorStream)
    let code = p.waitForExit()
    p.close()
    if code != 0:
      return 1
    result = max(1, outp.strip().splitLines().len)
  except CatchableError:
    result = 1

proc dimsOf(path: string): string =
  ## "WxH" via `sips`, or "" if sips can't read it (svg/video — soft: a
  ## metadata-hint miss must never abort the sort).
  try:
    let p = startProcess(
      "sips",
      args = ["-g", "pixelWidth", "-g", "pixelHeight", path],
      options = {poUsePath},
    )
    streams.close(p.inputStream)
    let outp = streams.readAll(p.outputStream)
    discard streams.readAll(p.errorStream)
    let code = p.waitForExit()
    p.close()
    if code != 0:
      return ""
    var w, h: string
    for line in outp.splitLines():
      let s = line.strip()
      if s.startsWith("pixelWidth:"):
        w = s.split(':')[1].strip()
      elif s.startsWith("pixelHeight:"):
        h = s.split(':')[1].strip()
    if w.len > 0 and h.len > 0:
      result = w & "x" & h
  except CatchableError:
    result = ""

proc humanSize(bytes: BiggestInt): string =
  ## Rough human-readable byte size for the metadata hint.
  if bytes < 1024:
    $bytes & " B"
  elif bytes < 1024 * 1024:
    $(bytes div 1024) & " KB"
  else:
    $(bytes div (1024 * 1024)) & " MB"

proc main() =
  # Hazel / launchd invoke us with a minimal PATH that omits ~/.local/bin,
  # where llm-local lives — prepend it so the vision call resolves regardless
  # of the caller's environment.
  let localBin = getHomeDir() / ".local" / "bin"
  putEnv("PATH", localBin & ":" & getEnv("PATH"))

  var dryRun = false
  var model = defaultModel
  var positional: seq[string]
  let params = commandLineParams()
  var i = 0
  while i < params.len:
    let a = params[i]
    case a
    of "--dry-run", "-n":
      dryRun = true
    of "-m", "--model":
      inc i
      if i >= params.len:
        fail("missing value for " & a & " (expected a model id)")
      model = params[i]
    else:
      positional.add a
    inc i
  if positional.len < 1 or positional.len > 2:
    stderr.writeLine "usage: image-sort [--dry-run|-n] [-m|--model <id>] <input-file> [root]"
    quit(1)
  let
    input = positional[0]
    root =
      if positional.len >= 2 and positional[1].len > 0:
        positional[1]
      else:
        getHomeDir() / defaultRootRel

  if not fileExists(input):
    fail("not a file: " & input)
  # Never disturb the curated reference set. image-sort only ever WRITES to
  # Lulu/<style> (style ∈ knownStyles ∪ "misc"), so it structurally cannot move
  # anything INTO Lulu/_references — but guard explicitly so a future routing
  # change or a stray manual run can't touch the references in either direction.
  if "_references" in input.split(DirSep):
    skip(
      "refusing to touch reference file under _references/ (" & input.extractFilename &
        ")"
    )
  let ext = input.splitFile().ext.toLowerAscii()
  if ext notin imageExts:
    skip("skipping unsupported extension '" & ext & "' (" & input.extractFilename & ")")

  # Working PNG for the vision call. The model can't read HEIC, so normalize
  # to PNG via sips. An ANIMATED gif (frame count > 1) instead becomes a 4x3
  # mosaic of ~12 evenly-sampled frames (ffmpeg `tile`), so the model sees the
  # whole animation rather than just frame 1.
  let workDir = createTempDir("image-sort-", "")
  defer:
    removeDir(workDir)
  var workPng = workDir / "work.png"
  let isVideo = ext in videoExts
  let isAnimatedGif = ext == ".gif" and gifFrames(input) > 1
  let useMosaic = isVideo or isAnimatedGif
  if ext == ".png":
    # Already a PNG in the target format — classify it in place (no copy). It's
    # moved into the library as-is below (keepOriginal), so nothing is converted
    # or trashed; this is why a re-sorted PNG no longer leaves a dupe in Trash.
    workPng = input
  elif ext == ".svg":
    # Rasterize the vector with resvg (pure-Rust, fast) just to classify it;
    # the original .svg is what we keep (see keepOriginal below).
    discard run("resvg", [input, workPng])
  elif useMosaic:
    # Animations/clips → a gif-mosaic contact sheet so the model sees the whole
    # motion, not frame 1. Gifs are forced through (short by nature). Videos are
    # NOT forced, so gif-mosaic's size/duration guard rejects a full movie —
    # which we then skip rather than misfile a feature film into the library.
    let args =
      if isVideo:
        @["--output", workPng, input]
      else:
        @["--force", "--output", workPng, input]
    if not tryRun("gif-mosaic", args):
      skip(
        "skipping " & input.extractFilename & " — gif-mosaic declined it " &
          "(looks like a full-length video over the size/duration guard, not a clip)"
      )
  else:
    # heic/heif/jpg/jpeg/webp/avif + static gif → sips raster → png.
    discard run("sips", ["-s", "format", "png", input, "--out", workPng])

  var llmArgs = @[
    "run", "-m", model, "--schema", "image-sort", "--promptFile", "image-sort", "-i",
    workPng,
  ]
  if useMosaic:
    # The model is looking at a tiled grid — tell it to judge the content, not
    # the grid, so the name/category reflect the animation's actual subject.
    llmArgs.add(
      "NOTE: the attached image is a grid of frames sampled from an animation " &
        "(gif or short video). Classify and name it by the animation's actual " &
        "subject, treating the grid as one scene — do not call it a grid, " &
        "mosaic, or contact sheet."
    )
  # Routing hints the pixels alone don't carry: the ORIGINAL format (a render of
  # an .svg looks like flat art → easily mistaken for a wallpaper), plus file size
  # and pixel dimensions (an icon-sized/tiny asset is not a wallpaper; a large
  # screen-shaped image usually is). Appended as text for the model to weigh.
  let origFormat = ext.strip(chars = {'.'}).toUpperAscii()
  var dims = ""
  if not useMosaic:
    dims = dimsOf(input)
    if dims.len == 0:
      dims = dimsOf(workPng) # svg: the original vector is unmeasurable by sips
  var meta =
    "original format " & origFormat & ", file size " & humanSize(getFileSize(input))
  if dims.len > 0:
    meta.add(", pixel dimensions " & dims)
  llmArgs.add(
    "FILE METADATA (context, not part of the image): " & meta & ". Weigh it " &
      "when routing — a vector (SVG) or an icon/tiny/low-resolution asset is " &
      "usually 'other' (app icon, logo, sticker), NOT a 'wallpaper'; only a " &
      "large, screen-shaped image (~1920x1080 or bigger) is a true wallpaper."
  )
  let raw = run("llm-local", llmArgs)

  var c: Classification
  try:
    c = Json.decode(raw, Classification, allowUnknownFields = true)
  except CatchableError as e:
    fail("could not decode classification: " & e.msg & "\n---\n" & raw)

  let category = c.category.get("").strip()
  if category.len == 0:
    fail("classifier returned no category (raw: " & raw & ")")
  let nsfw = c.nsfw.get(false)
  let slug = slugify(c.name.get(""))

  case category
  of "other":
    # Move the ORIGINAL verbatim — no conversion, no rename.
    let dest = root / "Other"
    let (_, base, oext) = input.splitFile()
    let final = uniquePath(dest, base, oext)
    if dryRun:
      stderr.writeLine("image-sort [dry-run]: " & input & " -> " & final & " [other]")
    else:
      createDir(dest)
      moveFile(input, final)
      stderr.writeLine("image-sort: " & input & " -> " & final & " [other]")
  of "screenshot", "lulu", "meme", "wallpaper":
    if slug.len == 0:
      fail(
        "classifier returned empty/unusable name for " & category & " (raw: " & raw & ")"
      )
    var dest: string
    case category
    of "screenshot":
      dest = root / "Screenshots"
    of "meme":
      dest = root / "Memes"
    of "wallpaper":
      dest = root / "Wallpapers"
      if nsfw:
        dest = dest / "nsfw"
    else: # lulu
      let style = c.style.get("none")
      let styleDir = if style in knownStyles: style else: "misc"
      dest = root / "Lulu" / styleDir
      if nsfw:
        dest = dest / "nsfw"
    # png/gif/svg/video already ARE the file we want to keep — move the original
    # (renamed) directly. A png needs no conversion (it was classified in place);
    # a gif keeps its animation, a video its clip, an svg its vector. Only formats
    # we actually convert (heic/jpg/jpeg/webp/avif) land as a new sips PNG with the
    # original trashed — so a PNG no longer gets needlessly copied-then-trashed.
    let keepOriginal = ext == ".png" or ext == ".gif" or ext == ".svg" or isVideo
    let outExt = if keepOriginal: ext else: ".png"
    let final = uniquePath(dest, slug, outExt)
    if dryRun:
      stderr.writeLine(
        "image-sort [dry-run]: " & input & " -> " & final & " [" & category & "]"
      )
    else:
      createDir(dest)
      if keepOriginal:
        moveFile(input, final) # move the original (renamed), no trash
      else:
        moveFile(workPng, final)
        trashOrDelete(input)
      stderr.writeLine("image-sort: " & input & " -> " & final & " [" & category & "]")
  else:
    fail("classifier returned unknown category '" & category & "' (raw: " & raw & ")")

when isMainModule:
  main()
