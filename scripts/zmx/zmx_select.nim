## zmx-select — fuzzy session picker: fzf over the zmx sessions with a live
## scrollback preview, then attach.
##
##   Enter    attach the highlighted session, or create one from the typed
##            query when nothing matches
##   Ctrl-N   create a session from the query even when a match is highlighted
##   Ctrl-S   toggle between every session and those in this directory
##   Ctrl-X   kill the highlighted session, then refresh the list
##   Ctrl-C   cancel
##
## The session you are in is never listed. Sessions in the current directory
## come first; the rest are grouped by directory.
##
## This process becomes fzf, and fzf becomes `zmx attach`. fzf builds its list
## by running this binary with `--emit`, and the prompt carries the mode:
## `zmx> ` is every session, `zmx cwd> ` is this directory only.
##
## Built to ~/.local/bin/zmx-select by run_onchange_build-scripts.sh.tmpl.

import std/[os, strutils]
from std/posix import execv, strerror, errno
import cligen
import zmx_snapshot, zmx_picker, term_out

const
  PromptAll = "zmx> "
  PromptHere = "zmx cwd> "
  # The name comes from the highlighted row, else the query; with neither there
  # is nothing to attach to. Ctrl-N asks them in the other order.
  Attach = "; [ -n \"$n\" ] || exit 130; exec zmx attach \"$n\")"

proc emitRows(here: bool): int =
  let views = snapshot().valueOr:
    stderr.writeLine "zmx-select: " & error
    return 1
  var home = getHomeDir()
  home.removeSuffix('/')
  let rows = pickerRows(
    views,
    getEnv("PWD", getCurrentDir()),
    here,
    home,
    getEnv("CHEZMOI_SOURCE_DIR", home & "/.local/share/chezmoi"),
  )
  for line in layout(rows):
    echo line
  0

proc zmxSelect(here = false, emit = false): int =
  ## Pick a zmx session with fzf and attach to it.
  ##
  ## Enter attaches the highlighted session, or creates one from the query when
  ## nothing matches. Ctrl-N creates from the query, Ctrl-S toggles this
  ## directory only, Ctrl-X kills the highlighted session, Ctrl-C cancels.
  if emit:
    return emitRows(here)

  pinEnvironment()
  if findExe("zmx").len == 0:
    stderr.writeLine "zmx-select: zmx not found"
    return 127
  let fzf = findExe("fzf")
  if fzf.len == 0:
    stderr.writeLine "zmx-select: fzf not found"
    return 127

  let
    self = quoteShell(getAppFilename())
    # --emit goes last: cligen leaves a flag hidden from --help off its list of
    # valueless flags, so it would take a following flag as its value.
    listAll = self & " --emit"
    listHere = self & " --here --emit"
    isAll = "[ \"$FZF_PROMPT\" = \"" & PromptAll & "\" ]"
  # fzf runs this for its list, but only when its stdin is a terminal.
  putEnv("FZF_DEFAULT_COMMAND", if here: listHere else: listAll)
  let args = @[
    fzf,
    "--with-shell",
    "/bin/sh -c",
    "--height=80%",
    "--reverse",
    "--prompt",
    (if here: PromptHere else: PromptAll),
    "--header",
    [
      "Enter: attach", "Ctrl-N: new", "Ctrl-S: cwd-only", "Ctrl-X: kill",
      "Ctrl-C: cancel",
    ].join(" " & Middot & " "),
    "--preview",
    "zmx history {1} --vt",
    "--preview-window",
    "right:60%:follow",
    "--bind",
    "ctrl-s:transform:" & isAll & " && echo \"change-prompt(" & PromptHere & ")+reload(" &
      listHere & ")\" || echo \"change-prompt(" & PromptAll & ")+reload(" & listAll &
      ")\"",
    "--bind",
    "ctrl-x:execute-silent(zmx kill {1})+transform:" & isAll & " && echo \"reload(" &
      listAll & ")\" || echo \"reload(" & listHere & ")\"",
    "--bind",
    "enter:become(n={1}; [ -n \"$n\" ] || n={q}" & Attach,
    "--bind",
    "ctrl-n:become(n={q}; [ -n \"$n\" ] || n={1}" & Attach,
  ]
  let argv = allocCStringArray(args)
  discard execv(fzf.cstring, argv)
  deallocCStringArray(argv)
  stderr.writeLine "zmx-select: could not run fzf: " & $strerror(errno)
  1

when isMainModule:
  cgParseErrorExitCode = 2
  clCfg.longPfxOk = false
  dispatch zmxSelect,
    cmdName = "zmx-select",
    short = {"here": '\0', "emit": '\0'},
    help = {
      "here": "start with only the sessions in this directory",
      # The list fzf reloads, hidden from --help. This is the default of
      # clCfg.hTabSuppress, spelled out because cligen reads the table in a macro.
      "emit": "CLIGEN-NOHELP",
    }
