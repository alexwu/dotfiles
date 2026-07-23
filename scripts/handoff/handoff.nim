## handoff — locate and name session-handoff docs for the current repo.
##
## A deterministic path/listing helper shared by the `handoff` and `pickup`
## skills, so the on-disk filename format lives in ONE place and can't drift
## between the writer and the reader. It only computes paths and lists files;
## it never writes a handoff's contents (the agent does) and knows nothing
## about beads or GitHub — that logic lives in the skills.
##
## Docs live at `<repo-root>/.handoff/<YYYY-MM-DD-HHMM>-<slug>.md`. The repo
## root is `git rev-parse --show-toplevel`; outside a git repo it falls back to
## the working directory.
##
## Subcommands (cligen dispatchMulti):
##   handoff list [--json]     list this repo's handoffs, newest first
##   handoff new <slug...>     print a fresh timestamped path to write into
##   handoff latest            print the newest handoff's path (exit 1 if none)
##   handoff dir               print the repo's .handoff/ directory
##
## Each subcommand takes -C/--directory to target another repo (like git -C).

import std/[algorithm, json, os, osproc, strutils, times]

type Handoff = object
  path: string ## absolute path to the .md file
  file: string ## basename, e.g. "2026-07-23-1430-fix-retry.md"
  stamp: string ## raw stamp prefix, "2026-07-23-1430" (or "" if malformed)
  slug: string ## slug after the stamp
  title: string ## first `# ` heading, or ""

proc gitRoot(dir: string): string =
  ## Repo root for `dir`, or the absolute `dir` itself outside a git repo.
  let (outp, code) = execCmdEx("git -C " & quoteShell(dir) & " rev-parse --show-toplevel")
  if code == 0 and outp.strip.len > 0:
    outp.strip
  else:
    absolutePath(dir)

proc handoffDir(directory: string): string =
  let base = if directory.len > 0: directory else: getCurrentDir()
  gitRoot(base) / ".handoff"

func slugify(s: string): string =
  ## Lowercase kebab-case, [a-z0-9] only, collapsed dashes, capped at 60 chars.
  var prevDash = false
  for c in s.toLowerAscii:
    if c in {'a' .. 'z', '0' .. '9'}:
      result.add c
      prevDash = false
    elif not prevDash and result.len > 0:
      result.add '-'
      prevDash = true
  result = result.strip(chars = {'-'})
  if result.len > 60:
    result = result[0 .. 59].strip(chars = {'-'})

proc firstTitle(path: string): string =
  try:
    for line in lines(path):
      let t = line.strip
      if t.startsWith("# "):
        return t[2 ..^ 1].strip
  except CatchableError:
    discard
  ""

func prettyStamp(stamp: string): string =
  ## "2026-07-23-1430" -> "2026-07-23 14:30"; pass through anything malformed.
  if stamp.len == 15 and stamp[10] == '-':
    stamp[0 .. 9] & " " & stamp[11 .. 12] & ":" & stamp[13 .. 14]
  else:
    stamp

proc gather(directory: string): seq[Handoff] =
  let d = handoffDir(directory)
  if not dirExists(d):
    return
  try:
    for kind, path in walkDir(d):
      if kind == pcFile and path.endsWith(".md"):
        let name = splitFile(path).name
        result.add Handoff(
          path: path,
          file: path.extractFilename,
          stamp: (if name.len >= 15: name[0 .. 14] else: ""),
          slug: (if name.len >= 16: name[16 ..^ 1] else: name),
          title: firstTitle(path),
        )
  except OSError:
    discard
  # Filename stamp sorts lexically == chronologically; newest first.
  result.sort(
    proc(a, b: Handoff): int =
      cmp(b.file, a.file)
  )

proc fail(msg: string) =
  stderr.writeLine("handoff: " & msg)
  quit(1)

# ---- subcommands ----

proc listCmd(json = false, directory = "") =
  ## List this repo's handoffs, newest first.
  let docs = gather(directory)
  if json:
    var arr = newJArray()
    for h in docs:
      arr.add %*{
        "path": h.path,
        "file": h.file,
        "stamp": h.stamp,
        "slug": h.slug,
        "title": h.title,
      }
    echo arr.pretty
    return
  if docs.len == 0:
    stderr.writeLine("handoff: no handoffs in " & handoffDir(directory))
    return
  var slugW = 4
  for h in docs:
    slugW = max(slugW, h.slug.len)
  echo alignLeft("WHEN", 16) & "  " & alignLeft("SLUG", slugW) & "  TITLE"
  for h in docs:
    echo alignLeft(prettyStamp(h.stamp), 16) & "  " & alignLeft(h.slug, slugW) & "  " & h.title

proc newCmd(slug: seq[string], directory = "") =
  ## Print a fresh timestamped handoff path (creates .handoff/ if needed).
  let s = slugify(slug.join(" "))
  if s.len == 0:
    stderr.writeLine("handoff: new needs a slug — e.g. handoff new fix retry wrapper")
    quit(2)
  let d = handoffDir(directory)
  try:
    createDir(d)
  except OSError as e:
    fail("can't create " & d & " — " & e.msg)
  echo d / (now().format("yyyy-MM-dd-HHmm") & "-" & s & ".md")

proc latestCmd(directory = "") =
  ## Print the newest handoff's path; exit 1 if there are none.
  let docs = gather(directory)
  if docs.len == 0:
    fail("no handoffs in " & handoffDir(directory))
  echo docs[0].path

proc dirCmd(directory = "") =
  ## Print the repo's .handoff/ directory path.
  echo handoffDir(directory)

when isMainModule:
  import cligen

  clCfg.version = "handoff 0.1.0"
  dispatchMulti(
    [listCmd, cmdName = "list", short = {"directory": 'C'},
      help = {"json": "emit records instead of a table", "directory": "repo to target (like git -C)"}],
    [newCmd, cmdName = "new", short = {"directory": 'C'},
      help = {"directory": "repo to target (like git -C)"}],
    [latestCmd, cmdName = "latest", short = {"directory": 'C'},
      help = {"directory": "repo to target (like git -C)"}],
    [dirCmd, cmdName = "dir", short = {"directory": 'C'},
      help = {"directory": "repo to target (like git -C)"}],
  )
