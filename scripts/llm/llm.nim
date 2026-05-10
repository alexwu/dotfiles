## llm: one-shot wrapper over the agentic CLIs (claude -p / codex exec / gemini -p)
## for non-interactive, pure-inference queries.
##
## Reads stdin if piped, joins it with a positional prompt using a codex-style
## ``<stdin>...</stdin>`` block, and dispatches to the chosen provider with
## defaults that disable tool generation (where the CLI supports it) and
## suppress session persistence (where the CLI supports it).
##
## Usage:
##   llm "what is 2+2"
##   echo "hello" | llm "translate to french"
##   git diff | llm --provider claude "write a conventional commit message"
##   llm --provider gemini -m gemini-2.5-pro "summarize this paper" < paper.txt
##
## Defaults (per provider):
##   claude   -p PROMPT --tools "" --output-format text --no-session-persistence
##            --append-system-prompt CLI_DIRECTIVE
##   codex    exec PROMPT -s read-only --skip-git-repo-check --ephemeral
##            --ignore-user-config   (wrapped via `sh -c 'exec codex … 2>/dev/null'`)
##   gemini   -p PROMPT --approval-mode plan
##
## All providers also receive a CLI-mode directive prepended to the merged
## prompt. The directive tells the model to behave as a non-interactive CLI
## (no preamble, no roleplay, no action beats), suppressing persona output
## that otherwise leaks in from user-level CLAUDE.md / codex personality.
##
## Notes:
##   - Default provider is codex.
##   - claude does NOT use ``--bare`` (bypasses Max OAuth).
##   - codex has no flag to disable tool-call generation entirely; the
##     ``-s read-only`` sandbox is the closest practical lock-down.
##   - codex's stderr is redirected to /dev/null to silence its verbose
##     banner / header / hook events (it puts only the answer on stdout).
##     Trade-off: real codex errors are also suppressed; for debugging,
##     invoke ``codex exec`` directly.
##   - gemini has no native ``--ephemeral`` / ``--no-session`` equivalent;
##     sessions persist on disk. Accepted gap; not auto-cleaned.

import std/[strutils, terminal, posix]

import cligen

const MaxArgBytes = 256_000
  ## Conservative cap (~25% of macOS ``ARG_MAX`` ~= 1MiB) leaving headroom
  ## for envp + other argv. Larger merged prompts get a clear error rather
  ## than a cryptic ``execvp`` failure.

const CliModeDirective =
  "You are running as a non-interactive CLI tool for a one-shot query. " &
  "Respond with only the requested answer. No preamble, no closing questions, " &
  "no narration of your reasoning, no roleplay prose, and absolutely no action " &
  "beats (do not emit *italicized actions* like \"*She tilts her head*\"). " &
  "Plain prose or code only."
  ## Prepended to every merged prompt and (for claude) wired in via
  ## ``--append-system-prompt``. Suppresses persona / action-beat output that
  ## leaks in from user-level CLAUDE.md, codex personality settings, etc.

proc readStdinIfPiped(): string =
  ## Drain stdin if piped; return empty string if attached to a TTY.
  ## ``terminal.isatty`` operates on ``File`` directly (not the cint that
  ## ``std/posix.isatty`` takes).
  if isatty(stdin):
    return ""
  return stdin.readAll()

proc mergePrompt(promptParts: seq[string], stdinText: string): string =
  ## Join positional prompt args (space-separated) with piped stdin using
  ## codex-style XML-ish demarcation so the model sees a clear boundary.
  ## Prepends ``CliModeDirective`` to suppress persona / action-beat output.
  let prompt = promptParts.join(" ").strip()
  let stdinTrimmed = stdinText.strip()
  if prompt.len == 0 and stdinTrimmed.len == 0:
    return ""
  let body =
    if stdinTrimmed.len == 0:
      prompt
    elif prompt.len == 0:
      stdinTrimmed
    else:
      prompt & "\n\n<stdin>\n" & stdinTrimmed & "\n</stdin>"
  result = CliModeDirective & "\n\n" & body

proc buildArgv(provider, model, merged: string): seq[string] =
  ## Pure-inference defaults per provider, with optional ``--model`` override.
  case provider
  of "claude":
    # --append-system-prompt layers the CLI directive above the user-level
    # CLAUDE.md persona, which otherwise leaks action beats into the answer.
    result = @[
      "claude", "-p", merged, "--tools", "", "--output-format", "text",
      "--no-session-persistence", "--append-system-prompt", CliModeDirective,
    ]
    if model.len > 0:
      result.add(@["--model", model])
  of "codex":
    # codex exec puts the answer on stdout and EVERYTHING ELSE on stderr —
    # version banner, header block, prompt echo, <stdin> echo, hook events,
    # and the "tokens used" footer. There's no --quiet flag, so we wrap in
    # `sh -c 'exec codex … 2>/dev/null'`: stderr → /dev/null, the inner
    # `exec` hands the process to codex so its exit code propagates cleanly.
    # Trade-off: real codex errors (auth, network) are also suppressed; for
    # debugging, invoke `codex exec` directly.
    # --ignore-user-config skips ~/.codex/config.toml (which carries the
    # `personality = "friendly"` setting and `project_doc_fallback_filenames`
    # that auto-loads the local CLAUDE.md). Auth still uses CODEX_HOME per
    # codex's docs, so subscription remains intact.
    var codexArgs = @[
      merged, "-s", "read-only", "--skip-git-repo-check", "--ephemeral",
      "--ignore-user-config",
    ]
    if model.len > 0:
      codexArgs.add(@["-m", model])
    result =
      @["sh", "-c", "exec codex exec \"$@\" 2>/dev/null", "llm-codex-shim"] & codexArgs
  of "gemini":
    # NOTE(alexwu): gemini has no --ephemeral / --no-session flag; sessions
    # always persist. --approval-mode plan keeps it read-only (verified
    # empirically against gemini -p in Phase 4.5 Step 1).
    result = @["gemini", "-p", merged, "--approval-mode", "plan"]
    if model.len > 0:
      result.add(@["-m", model])
  else:
    stderr.writeLine "llm: unknown provider: " & provider &
      " (expected claude | codex | gemini)"
    quit(2)

proc dispatchProvider(argv: seq[string]) {.noreturn.} =
  ## Replace the current process with the chosen provider so its stdout,
  ## stderr, and exit code propagate to the caller untouched.
  ##
  ## Redirect stdin -> /dev/null first: we already drained the original pipe
  ## and pre-merged it into argv, so leaving fd 0 attached to the (now-EOF)
  ## pipe could trick codex's native "stdin is piped -> wrap as <stdin>"
  ## path into double-wrapping our prompt. Bail loudly on redirect failure
  ## rather than silently shipping a half-broken setup.
  let devnull = posix.open("/dev/null", O_RDONLY)
  if devnull < 0:
    stderr.writeLine "llm: open(/dev/null) failed: " & $strerror(errno)
    quit(1)
  if posix.dup2(devnull, 0) == -1:
    stderr.writeLine "llm: dup2 stdin -> /dev/null failed: " & $strerror(errno)
    quit(1)
  discard posix.close(devnull)

  var cargs = allocCStringArray(argv) # from `system`, not `std/posix`
  # No defer/dealloc: execvp replaces the process on success; on failure we
  # exit immediately so the leak is harmless.
  discard execvp(argv[0].cstring, cargs)
  stderr.writeLine "llm: failed to exec " & argv[0] & ": " & $strerror(errno)
  deallocCStringArray(cargs)
  quit(127)

proc main(provider = "codex", model = "", prompt: seq[string]): int =
  ## One-shot wrapper over claude -p / codex exec / gemini -p.
  ##
  ## Reads stdin if piped, merges it with the positional prompt using a
  ## ``<stdin>`` block, and dispatches to the chosen provider in
  ## pure-inference mode (tools disabled or sandbox-locked, session
  ## persistence off where supported).
  let stdinText = readStdinIfPiped()
  let merged = mergePrompt(prompt, stdinText)
  if merged.len == 0:
    stderr.writeLine "llm: no prompt provided (pass as args or pipe via stdin)"
    return 2
  if merged.len > MaxArgBytes:
    stderr.writeLine "llm: merged prompt too large (" & $merged.len & " bytes; cap is " &
      $MaxArgBytes & "). Trim stdin or pass smaller input."
    return 2
  let argv = buildArgv(provider, model, merged)
  dispatchProvider(argv) # noreturn — control never reaches past this

when isMainModule:
  dispatch(
    main,
    cmdName = "llm",
    positional = "prompt",
    help = {
      "provider": "claude | codex | gemini (default: codex)",
      "model": "model override forwarded to backend as --model / -m",
      "prompt": "prompt text (joined with spaces if multi-arg)",
    },
  )
