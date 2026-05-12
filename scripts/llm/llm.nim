## llm: one-shot wrapper over the agentic CLIs (claude -p / codex exec / gemini -p / pi -p)
## for non-interactive, pure-inference queries.
##
## Piped stdin is passed straight through to the child CLI's own stdin — each
## tool then merges it with the positional prompt per its own convention:
##   - claude & codex append the piped input AFTER the prompt
##     (codex wraps it in a ``<stdin>...</stdin>`` block);
##   - gemini & pi prepend the piped input BEFORE the prompt.
## The wrapper only puts a small CLI-mode directive (+ the user's positional
## prompt) in argv, so the input-size ceiling is the model's context window,
## not the OS ``ARG_MAX``.
##
## Usage:
##   llm "what is 2+2"
##   echo "hello" | llm "translate to french"
##   git diff | llm --provider claude "write a conventional commit message"
##   llm --provider gemini -m gemini-2.5-pro "summarize this paper" < paper.txt
##
## Defaults (per provider):
##   claude   -p PROMPT_ARG --tools "" --output-format text
##            --no-session-persistence --append-system-prompt CLI_DIRECTIVE
##   codex    exec PROMPT_ARG -s read-only --skip-git-repo-check --ephemeral
##            --ignore-user-config   (wrapped via `sh -c 'exec codex … 2>/dev/null'`)
##   gemini   -p PROMPT_ARG --approval-mode plan
##   pi       -p PROMPT_ARG --provider llama-swap --model Qwen3.6-27B
##            --no-tools --no-session --mode text --no-skills --no-extensions
##            --no-prompt-templates --no-context-files
##            --append-system-prompt CLI_DIRECTIVE
##            (TS pi only — pi-rust currently disabled in buildArgv pending an
##             upstream fix to its print-mode streaming behavior.)
##            Always routes to local llama-swap; `--model` overrides the
##            default Qwen3.6-27B with another model from your llama-swap roster.
##
## PROMPT_ARG = the CLI-mode directive, then a blank line, then the user's
## positional prompt (or just the directive if the whole request arrived via
## stdin). The directive tells the model to behave as a non-interactive CLI
## (no preamble, no roleplay, no action beats) — this suppresses persona output
## that otherwise leaks in from user-level CLAUDE.md / codex personality
## settings — and, when stdin is piped, notes whether the piped content lands
## before or after this message for that provider.
##
## Notes:
##   - Default provider is codex.
##   - claude does NOT use ``--bare`` (bypasses Max OAuth).
##   - codex has no flag to disable tool-call generation entirely; the
##     ``-s read-only`` sandbox is the closest practical lock-down.
##   - codex's stderr is redirected to /dev/null to silence its verbose banner
##     / header / hook events (it puts only the answer on stdout). Trade-off:
##     real codex errors are also suppressed; for debugging, invoke
##     ``codex exec`` directly.
##   - gemini has no native ``--ephemeral`` / ``--no-session`` equivalent;
##     sessions persist on disk. Accepted gap; not auto-cleaned.
##   - pi uses the TS implementation only. `pi-rust` preference is disabled
##     (see NOTE in buildArgv) — its `-p` print mode currently redraws
##     progressive answer-states to a non-TTY stdout, producing duplicated
##     output when piped. Will revisit upstream.

import std/[strutils, terminal, posix]

import cligen

const MaxPromptArgBytes = 512_000
  ## Sanity cap on the argv-borne prompt (directive + positional prompt).
  ## Piped input no longer travels through argv — it streams to the child's
  ## stdin — so this only bites if you pass a huge string as the *positional*
  ## prompt (``llm "$(cat huge)"``), where the shell would usually fail with
  ## ``E2BIG`` first anyway. Over the cap → a clear error rather than a cryptic
  ## ``execvp`` failure.

const CliModeDirective =
  "You are running as a non-interactive CLI tool for a one-shot query. " &
  "Respond with only the requested answer. No preamble, no closing questions, " &
  "no narration of your reasoning, no roleplay prose, and absolutely no action " &
  "beats (do not emit *italicized actions* like \"*She tilts her head*\"). " &
  "Plain prose or code only."
  ## The persona-suppression core. Goes into the argv prompt for every provider
  ## and, for claude / pi, also via ``--append-system-prompt``.

const StdinAfterNote = " Any piped input follows immediately after this message."
  ## Appended to the directive for prompt-first providers (claude, codex), whose
  ## CLIs place the piped stdin after the positional prompt.

const StdinBeforeNote = " Any piped input precedes this message."
  ## Appended to the directive for stdin-first providers (gemini, pi), whose
  ## CLIs place the piped stdin before the positional prompt.

proc directiveFor(provider: string, stdinPiped: bool): string =
  ## CLI-mode directive, annotated (only when stdin is actually piped) with
  ## where the chosen child CLI places piped stdin relative to the argv prompt.
  if not stdinPiped:
    return CliModeDirective
  case provider
  of "claude", "codex":
    CliModeDirective & StdinAfterNote
  of "gemini", "pi":
    CliModeDirective & StdinBeforeNote
  else:
    CliModeDirective # unknown provider errors out later in buildArgv

proc buildPromptArg(directive, userPrompt: string): string =
  ## directive, then (if there's a positional prompt) a blank line and the
  ## prompt. When the whole request arrived via stdin, the argv prompt is just
  ## the directive — the piped content carries the question.
  if userPrompt.len == 0:
    directive
  else:
    directive & "\n\n" & userPrompt

proc buildArgv(provider, model, promptArg: string): seq[string] =
  ## Pure-inference defaults per provider, with optional ``--model`` override.
  ## ``promptArg`` is the directive (+ positional prompt) only — piped stdin is
  ## NOT folded in here; it streams to the child's own stdin.
  case provider
  of "claude":
    # --append-system-prompt layers the CLI directive above the user-level
    # CLAUDE.md persona, which otherwise leaks action beats into the answer.
    result = @[
      "claude", "-p", promptArg, "--tools", "", "--output-format", "text",
      "--no-session-persistence", "--append-system-prompt", CliModeDirective,
    ]
    if model.len > 0:
      result.add(@["--model", model])
  of "codex":
    # codex exec puts the answer on stdout and EVERYTHING ELSE on stderr —
    # version banner, header block, prompt echo, <stdin> echo, hook events,
    # and the "tokens used" footer. There's no --quiet flag, so we wrap in
    # `sh -c 'exec codex … 2>/dev/null'`: stderr → /dev/null, the inner
    # `exec` hands the process to codex so its exit code propagates cleanly
    # and the piped stdin is inherited intact.
    # Trade-off: real codex errors (auth, network) are also suppressed; for
    # debugging, invoke `codex exec` directly.
    # --ignore-user-config skips ~/.codex/config.toml (which carries the
    # `personality = "friendly"` setting and `project_doc_fallback_filenames`
    # that auto-loads the local CLAUDE.md). Auth still uses CODEX_HOME per
    # codex's docs, so subscription remains intact.
    var codexArgs = @[
      promptArg, "-s", "read-only", "--skip-git-repo-check", "--ephemeral",
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
    result = @["gemini", "-p", promptArg, "--approval-mode", "plan"]
    if model.len > 0:
      result.add(@["-m", model])
  of "pi":
    # Defaults to the local `llama-swap` provider (configured in
    # ~/.pi/agent/models.json -> http://127.0.0.1:8000/v1) with Qwen3.6-27B.
    # Overrides pi's own defaultProvider (cloud) — the wrapper exists for
    # local-first one-shots; cloud routing is what the other providers cover.
    #
    # NOTE(alexwu): pi-rust preference is disabled pending upstream fix.
    # pi-rust's `-p` (print) mode redraws progressive answer-states to a
    # non-TTY stdout, dumping N copies of the running answer when piped.
    # TS pi prints cleanly. Re-evaluate when pi-rust's print mode is fixed.
    #[ Disabled pi-rust-preferred resolution:
    var binary = findExe("pi-rust")
    var isRust = true
    if binary.len == 0:
      binary = findExe("pi")
      isRust = false
    if binary.len == 0:
      stderr.writeLine "llm: neither pi-rust nor pi found on PATH"
      quit(127)
    if not isRust:
      result.add(@["--no-context-files"])  # TS-only flag
    ]#
    let piModel = if model.len > 0: model else: "Qwen3.6-27B"
    result = @[
      "pi", "-p", promptArg, "--provider", "llama-swap", "--model", piModel,
      "--no-tools", "--no-session", "--mode", "text", "--no-skills", "--no-extensions",
      "--no-prompt-templates", "--no-context-files", "--append-system-prompt",
      CliModeDirective,
    ]
  else:
    stderr.writeLine "llm: unknown provider: " & provider &
      " (expected claude | codex | gemini | pi)"
    quit(2)

proc dispatchProvider(argv: seq[string]) {.noreturn.} =
  ## Replace the current process with the chosen provider so its stdin, stdout,
  ## stderr, and exit code all pass through to the caller untouched. Piped
  ## stdin (if any) is inherited by the child, which merges it with the argv
  ## prompt per its own convention; an attached TTY is harmless since every
  ## provider here only reads stdin when it's actually piped.
  var cargs = allocCStringArray(argv) # from `system`, not `std/posix`
  # No defer/dealloc: execvp replaces the process on success; on failure we
  # exit immediately so the leak is harmless.
  discard execvp(argv[0].cstring, cargs)
  stderr.writeLine "llm: failed to exec " & argv[0] & ": " & $strerror(errno)
  deallocCStringArray(cargs)
  quit(127)

proc main(provider = "codex", model = "", prompt: seq[string]): int =
  ## One-shot wrapper over claude -p / codex exec / gemini -p / pi -p.
  ##
  ## Piped stdin streams straight to the chosen provider's own stdin; only a
  ## CLI-mode directive (+ the positional prompt) goes through argv. Dispatches
  ## in pure-inference mode (tools disabled or sandbox-locked, session
  ## persistence off where supported).
  let stdinPiped = not isatty(stdin)
  let userPrompt = prompt.join(" ").strip()
  if userPrompt.len == 0 and not stdinPiped:
    stderr.writeLine "llm: no prompt provided (pass as args or pipe via stdin)"
    return 2
  let promptArg = buildPromptArg(directiveFor(provider, stdinPiped), userPrompt)
  if promptArg.len > MaxPromptArgBytes:
    stderr.writeLine "llm: prompt argument too large (" & $promptArg.len &
      " bytes; cap is " & $MaxPromptArgBytes &
      "). Pipe large input via stdin instead of passing it as an argument."
    return 2
  let argv = buildArgv(provider, model, promptArg)
  dispatchProvider(argv) # noreturn — control never reaches past this

when isMainModule:
  dispatch(
    main,
    cmdName = "llm",
    positional = "prompt",
    help = {
      "provider": "claude | codex | gemini | pi (default: codex)",
      "model": "model override forwarded to backend as --model / -m",
      "prompt": "prompt text (joined with spaces if multi-arg)",
    },
  )
