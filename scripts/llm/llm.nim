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
##   llm --system-prompt-file role.md "answer the question below"
##   git diff --cached | llm --prompt-file commit-message
##   llm --provider codex --schema pretooluse "should this tool call be denied?"
##   llm --provider codex --image diagram.png "explain this architecture"
##
## Extra inputs:
##   --system-prompt-file FILE  Markdown/text file layered onto the system
##     prompt, on top of the built-in CLI-mode directive. Supported by every
##     provider: claude & pi receive it via their ``--append-system-prompt``
##     flag; codex & gemini have no such flag, so it is folded into the argv
##     prompt instead.
##   --prompt-file NAME|FILE  Load the regular (positional) prompt from a file.
##     A bare NAME resolves against ~/.config/llm/prompts with .md / .txt
##     appended — so ``--prompt-file commit-message`` finds
##     ~/.config/llm/prompts/commit-message.md. Joined before any positional
##     prompt; for reusing saved prompts.
##   --schema NAME|FILE  JSON Schema for structured output. A bare NAME (no
##     path, no extension) resolves against ~/.config/llm/schemas — so
##     ``--schema pretooluse`` finds ~/.config/llm/schemas/pretooluse.schema.json.
##     A path or filename is taken as given, with .json / .schema.json appended
##     when missing. claude reads the file into ``--json-schema``; codex passes
##     the path to ``--output-schema``. gemini and pi have no structured-output
##     mechanism — passing --schema to either is a hard error.
##   --image FILE  Image to attach to the prompt (repeatable). codex uses
##     ``-i FILE``; pi takes an ``@FILE`` positional; gemini gets an ``@FILE``
##     mention appended to the prompt. claude -p has no tool-free image route —
##     passing --image to claude is a hard error.
##
## Defaults (per provider):
##   claude   -p PROMPT_ARG --tools "" --output-format text
##            --no-session-persistence --append-system-prompt CLI_DIRECTIVE
##   codex    exec PROMPT_ARG -s read-only --skip-git-repo-check --ephemeral
##            --ignore-user-config   (wrapped via `sh -c 'exec codex … 2>/dev/null'`)
##   gemini   -p PROMPT_ARG --approval-mode plan --skip-trust
##   pi       -p PROMPT_ARG --provider llama-swap --model Qwen3.6-27B
##            --no-tools --no-session --mode text --no-skills --no-extensions
##            --no-prompt-templates --no-context-files
##            --append-system-prompt CLI_DIRECTIVE
##            (TS pi only — pi-rust currently disabled in buildArgv pending an
##             upstream fix to its print-mode streaming behavior.)
##            Always routes to local llama-swap; `--model` overrides the
##            default Qwen3.6-27B with another model from your llama-swap roster.
##
## PROMPT_ARG = the CLI-mode directive, then (for codex/gemini) the
## --system-prompt-file contents, then the user's positional prompt — each
## separated by a blank line. When the whole request arrived via stdin, the
## argv prompt is just the directive (plus the folded system prompt, if any).
## The directive tells the model to behave as a non-interactive CLI (no
## preamble, no roleplay, no action beats) — this suppresses persona output
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

import std/[os, strutils, terminal, posix]

import cligen

const MaxPromptArgBytes = 512_000
  ## Sanity cap on the argv-borne prompt material (directive + positional
  ## prompt + --system-prompt-file contents + a claude --json-schema payload).
  ## Piped input does NOT travel through argv — it streams to the child's
  ## stdin — so this only bites if you pass a huge string as the *positional*
  ## prompt (``llm "$(cat huge)"``) or hand over a giant system-prompt/schema
  ## file. Over the cap → a clear error rather than a cryptic ``execvp``
  ## failure.

const KnownProviders = ["claude", "codex", "gemini", "pi"]
  ## Providers the wrapper knows how to dispatch.

const SchemaProviders = ["claude", "codex"]
  ## Providers with a structured-output mechanism for ``--schema``.

const ImageProviders = ["codex", "gemini", "pi"]
  ## Providers with an image-input path for ``--image``.

const SchemaDir = ".config/llm/schemas"
  ## ``--schema`` search dir, relative to ``$HOME``. A bare schema name (no
  ## path, no extension) resolves here, so ``--schema pretooluse`` finds the
  ## installed ``pretooluse.schema.json``.

const PromptDir = ".config/llm/prompts"
  ## ``--prompt-file`` search dir, relative to ``$HOME``. A bare prompt name
  ## (no path, no extension) resolves here, so ``--prompt-file commit-message``
  ## finds the installed ``commit-message.md``.

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

type LlmRequest = object ## A fully resolved one-shot request, ready for ``buildArgv``.
  provider: string
  model: string ## ``--model`` override; "" leaves the provider default.
  promptArg: string ## directive (+ folded system prompt) + positional prompt.
  systemPrompt: string
    ## --system-prompt-file contents, but only when the provider carries it via
    ## a system-prompt flag (claude, pi). "" for codex/gemini — there it is
    ## already folded into ``promptArg``.
  schemaContent: string ## --schema file contents (claude path); "" otherwise.
  schemaPath: string ## --schema file path (codex path); "" otherwise.
  images: seq[string] ## --image file paths, in argv order.

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
    CliModeDirective # unknown provider errors out earlier in main

proc buildPromptArg(directive, systemPrompt, userPrompt: string): string =
  ## The argv-borne prompt: the CLI-mode directive, then the system prompt
  ## (passed non-empty only for providers that lack a system-prompt flag — see
  ## ``main``), then the user's positional prompt. Empty pieces are dropped;
  ## the rest are joined by a blank line.
  var parts = @[directive]
  if systemPrompt.len > 0:
    parts.add(systemPrompt)
  if userPrompt.len > 0:
    parts.add(userPrompt)
  parts.join("\n\n")

proc buildArgv(req: LlmRequest): seq[string] =
  ## Pure-inference defaults per provider, with the resolved request's optional
  ## model, system prompt, schema, and images woven in. Piped stdin is NOT
  ## folded in here; it streams to the child's own stdin.
  case req.provider
  of "claude":
    # --append-system-prompt layers the CLI directive (plus any
    # --system-prompt-file contents) above the user-level CLAUDE.md persona,
    # which otherwise leaks action beats into the answer.
    var appendPrompt = CliModeDirective
    if req.systemPrompt.len > 0:
      appendPrompt &= "\n\n" & req.systemPrompt
    result = @[
      "claude", "-p", req.promptArg, "--tools", "", "--output-format", "text",
      "--no-session-persistence", "--append-system-prompt", appendPrompt,
    ]
    if req.model.len > 0:
      result.add(@["--model", req.model])
    if req.schemaContent.len > 0:
      result.add(@["--json-schema", req.schemaContent])
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
      req.promptArg, "-s", "read-only", "--skip-git-repo-check", "--ephemeral",
      "--ignore-user-config",
    ]
    if req.model.len > 0:
      codexArgs.add(@["-m", req.model])
    if req.schemaPath.len > 0:
      codexArgs.add(@["--output-schema", req.schemaPath])
    for img in req.images:
      codexArgs.add(@["-i", img])
    result =
      @["sh", "-c", "exec codex exec \"$@\" 2>/dev/null", "llm-codex-shim"] & codexArgs
  of "gemini":
    # NOTE(alexwu): gemini has no --ephemeral / --no-session flag; sessions
    # always persist. --approval-mode plan keeps it read-only; --skip-trust
    # bypasses gemini's workspace-trust gate, which a non-interactive one-shot
    # can never answer (without it gemini exits 55 in any untrusted directory).
    # plan mode already blocks all writes / tool execution, so --skip-trust
    # grants no capability. Images ride gemini's `@file` mention syntax appended
    # to the prompt — gemini has no --image flag.
    var promptArg = req.promptArg
    for img in req.images:
      promptArg &= " @" & img
    result = @["gemini", "-p", promptArg, "--approval-mode", "plan", "--skip-trust"]
    if req.model.len > 0:
      result.add(@["-m", req.model])
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
    let piModel = if req.model.len > 0: req.model else: "Qwen3.6-27B"
    var appendPrompt = CliModeDirective
    if req.systemPrompt.len > 0:
      appendPrompt &= "\n\n" & req.systemPrompt
    # `@file` image mentions are positional args; pi's usage places them
    # ahead of the message (`pi @img.png "question"`).
    result = @["pi", "-p"]
    for img in req.images:
      result.add("@" & img)
    result.add(req.promptArg)
    result.add(
      @[
        "--provider", "llama-swap", "--model", piModel, "--no-tools", "--no-session",
        "--mode", "text", "--no-skills", "--no-extensions", "--no-prompt-templates",
        "--no-context-files", "--append-system-prompt", appendPrompt,
      ]
    )
  else:
    stderr.writeLine "llm: unknown provider: " & req.provider &
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

proc resolveUnder(value, dir: string, exts: openArray[string]): string =
  ## Resolve a file reference to a real path. Tries ``value`` as given and with
  ## each extension in ``exts`` appended; then repeats that search inside
  ## ``~/<dir>``. Returns the first hit, or "" when nothing matches — so a path
  ## or filename works as given, while a bare name resolves against the install
  ## dir with no path or extension. ``exts`` should include "" for the as-given
  ## case. Backs both ``--schema`` (SchemaDir) and ``--prompt-file`` (PromptDir).
  for base in [value, getHomeDir() / dir / value]:
    for ext in exts:
      let candidate = base & ext
      if fileExists(candidate):
        return candidate
  ""

proc main(
    provider = "codex",
    model = "",
    systemPromptFile = "",
    promptFile = "",
    schema = "",
    image: seq[string] = @[],
    prompt: seq[string],
): int =
  ## One-shot wrapper over claude -p / codex exec / gemini -p / pi -p.
  ##
  ## Piped stdin streams straight to the chosen provider's own stdin; only a
  ## CLI-mode directive (+ optional system prompt + positional prompt) goes
  ## through argv. Dispatches in pure-inference mode (tools disabled or
  ## sandbox-locked, session persistence off where supported).
  if provider notin KnownProviders:
    stderr.writeLine "llm: unknown provider: " & provider &
      " (expected claude | codex | gemini | pi)"
    return 2

  let stdinPiped = not isatty(stdin)
  var userPrompt = prompt.join(" ").strip()

  if promptFile.len > 0:
    let resolved = resolveUnder(promptFile, PromptDir, ["", ".md", ".txt"])
    if resolved.len == 0:
      stderr.writeLine "llm: prompt file not found: " & promptFile &
        " (looked relative to the current directory and in ~/" & PromptDir &
        ", with optional .md / .txt)"
      return 2
    let filePrompt = readFile(resolved).strip()
    userPrompt =
      if userPrompt.len > 0:
        filePrompt & "\n\n" & userPrompt
      else:
        filePrompt

  if userPrompt.len == 0 and not stdinPiped:
    stderr.writeLine "llm: no prompt provided " &
      "(pass as args, --prompt-file, or pipe via stdin)"
    return 2

  # Feature gaps are a hard error up front rather than a silent no-op.
  if schema.len > 0 and provider notin SchemaProviders:
    stderr.writeLine "llm: --schema is not supported by " & provider &
      " (use claude or codex)"
    return 2
  if image.len > 0 and provider notin ImageProviders:
    stderr.writeLine "llm: --image is not supported by " & provider &
      " (use codex, gemini, or pi)"
    return 2

  if systemPromptFile.len > 0 and not fileExists(systemPromptFile):
    stderr.writeLine "llm: system prompt file not found: " & systemPromptFile
    return 2
  var resolvedSchema = ""
  if schema.len > 0:
    resolvedSchema = resolveUnder(schema, SchemaDir, ["", ".json", ".schema.json"])
    if resolvedSchema.len == 0:
      stderr.writeLine "llm: schema not found: " & schema &
        " (looked relative to the current directory and in ~/" & SchemaDir &
        ", with optional .json / .schema.json)"
      return 2
  for img in image:
    if not fileExists(img):
      stderr.writeLine "llm: image file not found: " & img
      return 2

  let systemPrompt =
    if systemPromptFile.len > 0:
      readFile(systemPromptFile)
    else:
      ""

  # codex & gemini have no system-prompt flag, so their system prompt is folded
  # into the argv prompt; claude & pi receive it via --append-system-prompt.
  let foldSysIntoPrompt = provider in ["codex", "gemini"]

  var req = LlmRequest(provider: provider, model: model, images: image)
  req.promptArg = buildPromptArg(
    directiveFor(provider, stdinPiped),
    (if foldSysIntoPrompt: systemPrompt else: ""),
    userPrompt,
  )
  if not foldSysIntoPrompt:
    req.systemPrompt = systemPrompt
  if schema.len > 0:
    if provider == "claude":
      req.schemaContent = readFile(resolvedSchema)
    else:
      req.schemaPath = resolvedSchema # codex — passed to --output-schema

  let argvPromptBytes = req.promptArg.len + req.systemPrompt.len + req.schemaContent.len
  if argvPromptBytes > MaxPromptArgBytes:
    stderr.writeLine "llm: prompt material too large (" & $argvPromptBytes &
      " bytes; cap is " & $MaxPromptArgBytes &
      "). Pipe large input via stdin instead of passing it as an argument."
    return 2

  let argv = buildArgv(req)
  dispatchProvider(argv) # noreturn — control never reaches past this

when isMainModule:
  dispatch(
    main,
    cmdName = "llm",
    positional = "prompt",
    help = {
      "provider": "claude | codex | gemini | pi (default: codex)",
      "model": "model override forwarded to backend as --model / -m",
      "systemPromptFile":
        "markdown/text file layered onto the system prompt (all providers)",
      "promptFile":
        "load the regular prompt from a file; a bare name resolves in " &
        "~/.config/llm/prompts",
      "schema":
        "JSON Schema for structured output; a bare name resolves in " &
        "~/.config/llm/schemas (claude, codex only)",
      "image": "image file to attach, repeatable (codex, gemini, pi only)",
      "prompt": "prompt text (joined with spaces if multi-arg)",
    },
  )
