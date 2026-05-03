## heic-ai-rename — convert an image to PNG and rename via `pi -p` vision,
## then move the result into a destination folder. Designed for invocation
## from a Hazel rule.
##
## Usage: heic-ai-rename <input-file> <context-hint> <dest-folder> [model-spec]
##
## - <input-file>:   HEIC, HEIF, JPG, JPEG, or PNG. Other extensions error out.
## - <context-hint>: free-form string describing what these images are about.
##                   Biases the model toward more specific filenames, e.g.
##                   "Liquid Glass UI screenshot — iOS 26 design language".
## - <dest-folder>:  directory the renamed PNG ends up in. Created if missing.
## - [model-spec]:   optional pi `--model` argument. Supports `provider/id`
##                   form (e.g. `llama-swap/Qwen3.5-9B`, `anthropic/sonnet`)
##                   and a trailing `:thinking` for thinking models.
##                   Defaults to `llama-swap/Qwen3.5-9B`.
##
## On success the original input is moved to Trash (via the `trash` CLI) or
## deleted if `trash` is not on PATH. HEIC/HEIF/JPEG inputs are converted to
## PNG via `sips` before being shown to the model.

import std/[os, osproc, strutils, streams, tempfiles]

proc fail(msg: string) {.noreturn.} =
  stderr.writeLine "heic-ai-rename: " & msg
  quit(1)

proc run(cmd: string, args: openArray[string]): string =
  ## Run `cmd` with `args` (no shell). Returns trimmed stdout.
  ## Closes the child's stdin immediately (EOF) so tools like `claude` don't
  ## sit waiting on it. Drains stderr separately so a chatty stderr can't
  ## fill its pipe and deadlock the child. Aborts with `fail` on non-zero.
  let p = startProcess(cmd, args = args, options = {poUsePath})
  p.inputStream.close()
  let output = p.outputStream.readAll()
  let errOutput = p.errorStream.readAll()
  let exitCode = p.waitForExit()
  p.close()
  if exitCode != 0:
    let detail =
      if errOutput.strip().len > 0: errOutput.strip()
      else: output.strip()
    fail("`" & cmd & "` failed (exit " & $exitCode & "): " & detail)
  result = output.strip()

proc slugify(raw: string): string =
  ## Lowercase the string, drop a trailing `.png`, replace runs of non-alnum
  ## with a single `-`, and trim leading/trailing dashes.
  var lower = raw.toLowerAscii()
  if lower.endsWith(".png"):
    lower.setLen(lower.len - 4)
  result = newStringOfCap(lower.len)
  var prevDash = true # treat as dash so leading non-alnum gets stripped
  for ch in lower:
    if ch in {'a'..'z', '0'..'9'}:
      result.add ch
      prevDash = false
    elif not prevDash:
      result.add '-'
      prevDash = true
  if result.len > 0 and result[^1] == '-':
    result.setLen(result.len - 1)

const defaultModel = "llama-swap/Qwen3.5-9B"

proc main() =
  let args = commandLineParams()
  if args.len < 3 or args.len > 4:
    stderr.writeLine "usage: heic-ai-rename <input-file> <context-hint> <dest-folder> [model-spec]"
    quit(1)
  let
    input = args[0]
    context = args[1]
    dest = args[2]
    model = if args.len == 4: args[3] else: defaultModel

  if not fileExists(input):
    fail("not a file: " & input)
  createDir(dest)

  let ext = input.splitFile().ext.toLowerAscii() # includes leading dot
  let workDir = createTempDir("heic-ai-rename-", "")
  defer: removeDir(workDir)
  let workPng = workDir / "work.png"

  case ext
  of ".heic", ".heif", ".jpg", ".jpeg":
    discard run("sips",
                ["-s", "format", "png", input, "--out", workPng])
  of ".png":
    copyFile(input, workPng)
  else:
    fail("unsupported extension '" & ext & "'")

  let prompt = "Look at the attached image.\n\n" &
    "Context: " & context & "\n\n" &
    "Reply with EXACTLY ONE descriptive kebab-case filename. Constraints:\n" &
    "- Lowercase only\n" &
    "- 30-70 characters\n" &
    "- Hyphens between words; no spaces, no underscores\n" &
    "- No path, no file extension, no quotes, no markdown, no explanation\n" &
    "- If you can identify an app + component + relevant state, that's ideal: " &
      "e.g. safari-tab-bar-translucent-toolbar\n\n" &
    "Output ONLY the filename string. Nothing else."

  let raw = run("pi",
                ["-p", "--no-session", "--model", model,
                 "@" & workPng, prompt])
  let slug = slugify(raw)
  if slug.len == 0:
    fail("pi returned empty/unusable name (raw: " & raw & ")")

  var final = dest / (slug & ".png")
  var i = 2
  while fileExists(final):
    final = dest / (slug & "-" & $i & ".png")
    inc i

  moveFile(workPng, final)
  stderr.writeLine("heic-ai-rename: " & input & " -> " & final)

  let trashPath = findExe("trash")
  if trashPath.len > 0:
    discard run(trashPath, [input])
  else:
    removeFile(input)

when isMainModule:
  main()
