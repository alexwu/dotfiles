## image-sort — classify a Downloads image as lulu / screenshot / other via
## `llm-local` vision, then rename + route it into a sorted folder tree.
## Designed for invocation from a Hazel rule (or run manually, per file).
##
## Usage: image-sort [--dry-run|-n] <input-file> [root] [model]
##
## - --dry-run/-n: classify and print where the file WOULD go; move nothing.
## - <input-file>: HEIC, HEIF, JPG, JPEG, PNG, WEBP, or GIF. Else errors out.
## - [root]:       destination root for the sorted tree. Defaults to
##                 ~/Downloads/Images. Change this ONE path to relocate the
##                 whole library later (e.g. into BombeeCloud).
## - [model]:      llama-swap model id for `llm-local -m`. Defaults to
##                 Qwen3.6-35B-A3B-heretic (always-on = no cold-load,
##                 uncensored = classifies NSFW honestly instead of refusing).
##
## A single `llm-local --schema image-sort --promptFile image-sort` call
## returns { category, style, nsfw, name }. Routing under <root>:
##
##   lulu       -> Lulu/<style>/<name>.png          (nsfw -> Lulu/<style>/nsfw/)
##   screenshot -> Screenshots/<name>.png
##   other      -> Other/<original-filename>         (moved as-is, not renamed)
##
## For lulu/screenshot the working PNG (sips-converted) lands at the
## destination and the original is moved to Trash. For other, the ORIGINAL
## file is moved verbatim (format + name preserved) — no conversion, no rename.
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
  defaultModel = "Qwen3.6-35B-A3B-heretic"
  defaultRootRel = "Downloads/Images" # relative to $HOME
  knownStyles = ["realistic", "anime", "cartoon"]
  imageExts = [".heic", ".heif", ".jpg", ".jpeg", ".png", ".webp", ".gif"]

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
      if errOutput.strip().len > 0: errOutput.strip()
      else: output.strip()
    fail("`" & cmd & "` failed (exit " & $exitCode & "): " & detail)
  result = output.strip()

proc slugify(raw: string): string =
  ## Lowercase, drop a trailing `.png`, collapse runs of non-alnum to a single
  ## `-`, trim leading/trailing dashes.
  var lower = raw.toLowerAscii()
  if lower.endsWith(".png"):
    lower.setLen(lower.len - 4)
  result = newStringOfCap(lower.len)
  var prevDash = true
  for ch in lower:
    if ch in {'a'..'z', '0'..'9'}:
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

proc main() =
  # Hazel / launchd invoke us with a minimal PATH that omits ~/.local/bin,
  # where llm-local lives — prepend it so the vision call resolves regardless
  # of the caller's environment.
  let localBin = getHomeDir() / ".local" / "bin"
  putEnv("PATH", localBin & ":" & getEnv("PATH"))

  var dryRun = false
  var args: seq[string]
  for a in commandLineParams():
    if a == "--dry-run" or a == "-n": dryRun = true
    else: args.add a
  if args.len < 1 or args.len > 3:
    stderr.writeLine "usage: image-sort [--dry-run|-n] <input-file> [root] [model]"
    quit(1)
  let
    input = args[0]
    root = if args.len >= 2 and args[1].len > 0: args[1]
           else: getHomeDir() / defaultRootRel
    model = if args.len >= 3 and args[2].len > 0: args[2] else: defaultModel

  if not fileExists(input):
    fail("not a file: " & input)
  let ext = input.splitFile().ext.toLowerAscii()
  if ext notin imageExts:
    fail("unsupported extension '" & ext & "'")

  # Working PNG for the vision call (the model can't read HEIC; normalize all).
  let workDir = createTempDir("image-sort-", "")
  defer:
    removeDir(workDir)
  let workPng = workDir / "work.png"
  if ext == ".png":
    copyFile(input, workPng)
  else:
    discard run("sips", ["-s", "format", "png", input, "--out", workPng])

  let raw = run(
    "llm-local",
    [
      "run", "-m", model, "--schema", "image-sort", "--promptFile", "image-sort",
      "-i", workPng,
    ],
  )

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
  of "screenshot", "lulu":
    if slug.len == 0:
      fail("classifier returned empty/unusable name for " & category &
        " (raw: " & raw & ")")
    var dest: string
    if category == "screenshot":
      dest = root / "Screenshots"
    else:
      let style = c.style.get("none")
      let styleDir = if style in knownStyles: style else: "misc"
      dest = root / "Lulu" / styleDir
      if nsfw:
        dest = dest / "nsfw"
    let final = uniquePath(dest, slug, ".png")
    if dryRun:
      stderr.writeLine("image-sort [dry-run]: " & input & " -> " & final &
        " [" & category & "]")
    else:
      createDir(dest)
      moveFile(workPng, final)
      trashOrDelete(input)
      stderr.writeLine("image-sort: " & input & " -> " & final & " [" & category & "]")
  else:
    fail("classifier returned unknown category '" & category & "' (raw: " & raw & ")")

when isMainModule:
  main()
