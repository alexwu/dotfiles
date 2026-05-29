## gif-mosaic — render an animation (gif, animated webp, or short video) into a
## single 4x3 contact-sheet PNG of 12 evenly-spaced frames, so a viewer that
## can't see motion (an LLM agent) can take in the whole animation at once.
##
## Usage: gif-mosaic [--force] [--output PATH] <input>
##   <input>    any file ffmpeg reads — gif / webp / mp4 / mov / ...
##   --output   where to write the mosaic PNG. Omitted → a temp file whose
##              path is printed to stdout (so a caller can read it back).
##   --force    bypass the size/duration guard below.
##
## GUARD: refuses inputs over 200 MB or ~5 min unless --force — so you can't
## accidentally feed it a whole movie and have it grind. Even forced, it only
## ever samples 12 frames (cheap seeks, not a full decode).
##
## Sampling is timestamp-based: 12 frames at the midpoints of 12 equal slices
## of the duration, so coverage spans the WHOLE animation (start to end) rather
## than the first ~80% a frame-interval would give. Pure ffmpeg/ffprobe — no
## ImageMagick, no fonts.

import std/[os, osproc, streams, strutils, strformat, tempfiles]

const
  maxBytes = 200 * 1024 * 1024 # 200 MB — a gif/clip is well under; a movie isn't
  maxDuration = 300.0          # 5 minutes
  cells = 12                   # 4x3 grid
  cellWidth = 320              # px per frame

proc fail(msg: string) {.noreturn.} =
  stderr.writeLine "gif-mosaic: " & msg
  quit(1)

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

proc main(force = false, output = "", input: seq[string]) =
  if input.len != 1:
    fail("usage: gif-mosaic [--force] [--output PATH] <input>")
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
        &"(it still only samples {cells} frames)."
    )

  let work = createTempDir("gif-mosaic-", "")
  defer:
    removeDir(work)

  # 12 frames at the midpoints of 12 equal time-slices → even whole-animation
  # coverage. Input-seek (`-ss` before `-i`) is fast even on long inputs.
  for i in 0 ..< cells:
    let t = dur * (float(i) + 0.5) / float(cells)
    let frame = work / &"f{i:02}.png"
    let (code, _) = sh(
      "ffmpeg",
      [
        "-y", "-hide_banner", "-loglevel", "error", "-ss", $t, "-i", src,
        "-frames:v", "1", "-update", "1", frame,
      ],
    )
    if code != 0 or not fileExists(frame):
      fail(&"ffmpeg failed extracting a frame at {t:.2f}s")

  let outPath =
    if output.len > 0:
      output
    else:
      createTempDir("gif-mosaic-out-", "") / (src.splitFile.name & "-mosaic.png")

  let (code, _) = sh(
    "ffmpeg",
    [
      "-y", "-hide_banner", "-loglevel", "error", "-start_number", "0", "-i",
      work / "f%02d.png", "-vf", &"scale={cellWidth}:-1,tile=4x3", "-frames:v",
      "1", outPath,
    ],
  )
  if code != 0:
    fail("ffmpeg failed assembling the mosaic")

  echo outPath

when isMainModule:
  import cligen
  dispatch(
    main,
    help = {
      "force": "bypass the 200 MB / 5 min guard",
      "output": "write the mosaic PNG here (default: a temp file, path printed)",
    },
  )
