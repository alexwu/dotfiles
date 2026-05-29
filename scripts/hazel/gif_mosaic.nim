## gif-mosaic — render an animation (gif, animated webp, or short video) into a
## single contact-sheet PNG of evenly-spaced frames, so a viewer that can't see
## motion (an LLM agent) can take in the whole animation at once.
##
## Usage: gif-mosaic [--force] [--output PATH] [--cells N] [--aspect W:H]
##                   [--cell-width PX] <input>
##   <input>       any file ffmpeg reads — gif / webp / mp4 / mov / ...
##   --output      where to write the mosaic PNG. Omitted → a temp file whose
##                 path is printed to stdout (so a caller can read it back).
##   --force       bypass the size/duration guard below.
##   --cells       TARGET frame count (1-256, default 12). More frames span the
##                 timeline more finely → a more accurate read of the motion.
##                 Realized count is cols×rows after --aspect shapes the grid,
##                 so it lands near (not exactly) this number.
##   --aspect      grid shape as W:H (default 4:3), AUTHORITATIVE. cols×rows is
##                 shaped to this ratio holding ≈--cells frames — so changing it
##                 actually reshapes the mosaic (wide 16:9, square 1:1, ...).
##   --cell-width  px width per frame tile (default 400). Height auto-scales to
##                 preserve each frame's own aspect. 400 is the bang-for-buck
##                 knee — a vision model downscales bigger mosaics back to a
##                 fixed budget, so >~500px buys no extra clarity. Raise it for
##                 a human eyeballing the PNG; it's wasted on an LLM consumer.
##
## GUARD: refuses inputs over 200 MB or ~5 min unless --force — so you can't
## accidentally feed it a whole movie and have it grind. Even forced, it only
## ever samples --cells frames (cheap seeks, not a full decode).
##
## Sampling is timestamp-based: each frame is taken at the midpoint of one of
## --cells equal slices of the duration, so coverage spans the WHOLE animation
## (start to end) rather than the first ~80% a frame-interval would give. Pure
## ffmpeg/ffprobe — no ImageMagick, no fonts.

import std/[os, osproc, streams, strutils, strformat, math, tempfiles]

const
  maxBytes = 200 * 1024 * 1024 # 200 MB — a gif/clip is well under; a movie isn't
  maxDuration = 300.0          # 5 minutes
  maxCells = 256               # sanity ceiling — one ffmpeg seek per cell

proc fail(msg: string) {.noreturn.} =
  stderr.writeLine "gif-mosaic: " & msg
  quit(1)

proc grid(cells: int, aspect: string): tuple[cols, rows: int] =
  ## Shape a cols×rows grid whose ratio ≈ `aspect` (W:H) holding ≈`cells` frames.
  ## Aspect is AUTHORITATIVE: the grid takes the requested shape and `cells` is a
  ## target — the realized frame count is cols·rows. (Forcing cols·rows == cells
  ## exactly collapses every ratio to the same grid at low cell counts, e.g. 12
  ## only factors as 4×3 / 6×2 — so the aspect flag would do nothing. Letting the
  ## count flex a little is what makes the shape actually change.)
  ## rows = √(cells/r), cols = rows·r, with r = W/H.
  let parts = aspect.split(':')
  if parts.len != 2:
    fail("--aspect must be W:H (e.g. 4:3), got: " & aspect)
  var aw, ah: float
  try:
    aw = parseFloat(parts[0].strip())
    ah = parseFloat(parts[1].strip())
  except ValueError:
    fail("--aspect W and H must be numbers, got: " & aspect)
  if aw <= 0 or ah <= 0:
    fail("--aspect W and H must be positive, got: " & aspect)
  let r = aw / ah
  let rows = max(1, int(round(sqrt(cells.float / r))))
  let cols = max(1, int(round(rows.float * r)))
  (cols, rows)

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

proc durationSecs(path: string): float =
  ## Container duration in seconds via ffprobe, or -1 if unreadable.
  let (code, outp) = sh(
    "ffprobe",
    ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
  )
  if code != 0 or outp.len == 0:
    return -1
  try:
    parseFloat(outp.strip())
  except ValueError:
    -1

proc extractFrame(src: string, t, slice: float, dest: string): bool =
  ## Grab one frame at ~`t` seconds into `src`. Input-seek (`-ss` before `-i`)
  ## is fast but, on gifs especially, can overshoot past the final frame when
  ## `t` sits in the gap between the last frame's PTS and the container
  ## duration (likelier the more cells we sample). On a miss, step back by
  ## half-`slice` increments — the natural sampling granularity — until we land
  ## on a real frame. Worst case the last cell is a near-duplicate of the
  ## previous one, which beats aborting the whole mosaic.
  for attempt in 0 .. 5:
    let tt = max(0.0, t - 0.5 * slice * attempt.float)
    removeFile(dest) # clear any partial from a prior miss
    let (code, _) = sh(
      "ffmpeg",
      [
        "-y", "-hide_banner", "-loglevel", "error", "-ss", $tt, "-i", src,
        "-frames:v", "1", "-update", "1", dest,
      ],
    )
    if code == 0 and fileExists(dest):
      return true
  false

proc main(
    force = false, output = "", cells = 12, aspect = "4:3", cellWidth = 400,
    input: seq[string],
) =
  if input.len != 1:
    fail(
      "usage: gif-mosaic [--force] [--output PATH] [--cells N] [--aspect W:H] " &
        "[--cell-width PX] <input>"
    )
  if cells < 1 or cells > maxCells:
    fail(&"--cells must be 1-{maxCells}, got {cells}")
  if cellWidth < 1:
    fail(&"--cell-width must be a positive px value, got {cellWidth}")
  let (cols, rows) = grid(cells, aspect)
  let nFrames = cols * rows # realized count — aspect-shaped, ≈cells
  let src = input[0]
  if not fileExists(src):
    fail("not a file: " & src)

  if getFileSize(src) > maxBytes and not force:
    let mb = getFileSize(src) div (1024 * 1024)
    fail(
      &"{src} is {mb} MB — over the 200 MB cap (looks like a movie?). " &
        "Pass --force to proceed anyway."
    )

  let dur = durationSecs(src)
  if dur <= 0:
    fail("couldn't read a duration from " & src & " (is it an animation/video?)")
  if dur > maxDuration and not force:
    fail(
      &"{src} runs {dur:.0f}s — over the {maxDuration:.0f}s cap. Pass --force " &
        &"(it still only samples {nFrames} frames)."
    )

  let work = createTempDir("gif-mosaic-", "")
  defer:
    removeDir(work)

  # nFrames frames at the midpoints of nFrames equal time-slices → even
  # whole-animation coverage. Input-seek (`-ss` before `-i`) is fast even on
  # long inputs; extractFrame backs off if a sample overshoots the last frame.
  let slice = dur / nFrames.float
  for i in 0 ..< nFrames:
    let t = dur * (float(i) + 0.5) / float(nFrames)
    let frame = work / &"f{i:02}.png"
    if not extractFrame(src, t, slice, frame):
      fail(&"ffmpeg failed extracting a frame near {t:.2f}s")

  let outPath =
    if output.len > 0:
      output
    else:
      createTempDir("gif-mosaic-out-", "") / (src.splitFile.name & "-mosaic.png")

  let (code, _) = sh(
    "ffmpeg",
    [
      "-y", "-hide_banner", "-loglevel", "error", "-start_number", "0", "-i",
      work / "f%02d.png", "-vf", &"scale={cellWidth}:-1,tile={cols}x{rows}",
      "-frames:v", "1", outPath,
    ],
  )
  if code != 0:
    fail("ffmpeg failed assembling the mosaic")

  stderr.writeLine(&"gif-mosaic: {nFrames} frames in a {cols}x{rows} grid @ {cellWidth}px")
  echo outPath

when isMainModule:
  import cligen
  dispatch(
    main,
    help = {
      "force": "bypass the 200 MB / 5 min guard",
      "output": "write the mosaic PNG here (default: a temp file, path printed)",
      "cells": "frames to sample, 1-256 (more = finer timeline coverage)",
      "aspect": "grid shape W:H; cols x rows derived to hold --cells frames",
      "cellWidth": "px width per frame tile (height auto-scales)",
    },
  )
