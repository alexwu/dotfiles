## llm-local — one-shot wrapper over a llama-swap / llama.cpp / mlx-vlm
## OpenAI-compatible endpoint, mirroring the `llm` CLI's `--schema` /
## `--promptFile` / stdin-as-user conventions for the `run` subcommand,
## plus `models` and `running` subcommands that surface the rest of what
## llama-swap exposes.
##
## The point: every other provider in the `llm` family (claude, codex,
## gemini, pi) goes through its respective CLI, which adds a per-call
## process spawn on top of inference latency — typically 2-5s of pure
## overhead before any token is generated. For guard-class classifiers
## (truncation-guard, inline-script-guard) hitting a local llama-swap
## endpoint directly cuts that overhead to a single sub-second HTTP
## round-trip. A Qwen3.6-35B-A3B MoE behind llama-swap returns a strict
## structured-output decision in ~1.4 s warm; spark via codex sits at ~5 s.
##
## Subcommands:
##   run      — one-shot chat completion (the primary action)
##   models   — list models llama-swap exposes via /v1/models, with a
##              running indicator merged in from /running
##   running  — show currently-loaded models with state / backend / proxy
##
## Resolution rules for `run` match the `llm` CLI:
##   --schema      bare name → ~/.config/llm/schemas/<value>.schema.json
##   --promptFile  bare name → ~/.config/llm/prompts/<value>.md
##   Any value starting with `/`, `./`, or `../` is treated as an
##   explicit path and used verbatim. Bare names may contain inner `/`
##   to traverse subdirectories (e.g. `strict/pretooluse`).
##
## --baseUrl is the llama-swap **server root** (default
## http://localhost:8000). OpenAI endpoints live under /v1/...; llama-swap
## admin endpoints (/running, /health) sit at the root.
##
## Decoding uses `json_serialization` with typed Option[T] (per the repo
## convention — silent `getStr("")` fallbacks are how external schema
## drift hides). The outgoing chat-completion request body is composed
## with std/json because `response_format.json_schema.schema` embeds the
## caller's schema JsonNode verbatim, which is awkward with strongly-typed
## encode.

import std/[httpclient, os, sets, strutils, terminal]
import std/json as stdjson
import std/options as stdOptions
import json_serialization
import json_serialization/std/options as jsOptions

const
  DefaultBaseUrl = "http://localhost:8000"
  DefaultTemperature = 0.2
  DefaultMaxTokens = 4096
  DefaultTimeoutSecs = 60
  ListTimeoutSecs = 10
  ConfigSubpath = ".config/llm"

# Response decoding —– every field that upstream might omit is Option[T]
# so an unexpected null / absent field surfaces as None at decode time,
# not as a silent zero-value downstream. `allowUnknownFields = true` lets
# llama-server-specific fields (timings, system_fingerprint, ...) flow past.

type
  ResponseMessage = object
    role*: Option[string]
    content*: Option[string]

  ResponseChoice = object
    index*: Option[int]
    message*: Option[ResponseMessage]
    finish_reason*: Option[string]

  ResponseUsage = object
    prompt_tokens*: Option[int]
    completion_tokens*: Option[int]
    total_tokens*: Option[int]

  ChatResponse = object
    id*: Option[string]
    model*: Option[string]
    choices*: Option[seq[ResponseChoice]]
    usage*: Option[ResponseUsage]

  ApiErrorBody = object
    message*: Option[string]
    `type`*: Option[string]
    code*: Option[string]

  ApiErrorResponse = object
    error*: Option[ApiErrorBody]

  # /v1/models — llama-swap mostly returns the OpenAI baseline, but each
  # model can carry per-config name/description/metadata which we surface
  # if present.
  ModelInfo = object
    id*: Option[string]
    created*: Option[int]
    `object`*: Option[string]
    owned_by*: Option[string]
    name*: Option[string]
    description*: Option[string]
    aliases*: Option[seq[string]]

  ModelsResponse = object
    `object`*: Option[string]
    data*: Option[seq[ModelInfo]]

  # /running — the cmd / proxy / state / ttl per loaded model. `name` and
  # `description` are populated from per-model config if set.
  RunningModel = object
    model*: Option[string]
    state*: Option[string]
    proxy*: Option[string]
    cmd*: Option[string]
    ttl*: Option[int]
    name*: Option[string]
    description*: Option[string]

  RunningResponse = object
    running*: Option[seq[RunningModel]]

proc die(msg: string, code: int = 1) {.noreturn.} =
  stderr.styledWriteLine(fgRed, "llm-local: ", resetStyle, msg)
  quit(code)

proc resolveResource(value, subdir, suffix: string): string =
  ## Resolve a `--schema` / `--promptFile` value to an on-disk path.
  if value.len == 0:
    return ""
  let isExplicitPath =
    value.startsWith("/") or value.startsWith("./") or value.startsWith("../")
  if isExplicitPath:
    if fileExists(value):
      return value
    die("file not found: " & value)
  let home = getHomeDir()
  let withSuffix = home / ConfigSubpath / subdir / (value & suffix)
  if fileExists(withSuffix):
    return withSuffix
  let asSupplied = home / ConfigSubpath / subdir / value
  if fileExists(asSupplied):
    return asSupplied
  die(
    "cannot resolve " & subdir & " resource '" & value &
      "' (looked at " & withSuffix & " and " & asSupplied & ")"
  )

proc joinUrl(base, path: string): string =
  let b = base.strip(chars = {'/'}, leading = false)
  let p = path.strip(chars = {'/'}, trailing = false)
  b & "/" & p

type HttpResult = tuple[ok: bool, body: string, status: string]

proc httpGetRaw(url: string, timeoutSecs: int): HttpResult =
  let client = newHttpClient(timeout = timeoutSecs * 1000)
  defer:
    client.close()
  try:
    let resp = client.get(url)
    return (resp.status.startsWith("200"), resp.body, resp.status)
  except CatchableError as e:
    return (false, e.msg, "")

proc fetchRunningIds(baseUrl: string): HashSet[string] =
  ## Best-effort: returns an empty set if /running is unreachable rather
  ## than failing the caller (e.g. the `models` table still works without
  ## the running indicator when llama-swap admin endpoints are gated off).
  result = initHashSet[string]()
  let (ok, body, _) = httpGetRaw(joinUrl(baseUrl, "running"), ListTimeoutSecs)
  if not ok:
    return
  var parsed: RunningResponse
  try:
    parsed = Json.decode(body, RunningResponse, allowUnknownFields = true)
  except CatchableError:
    return
  if parsed.running.isNone:
    return
  for r in parsed.running.get:
    if r.model.isSome:
      result.incl r.model.get

proc backendFromCmd(cmd: string): string =
  ## "llama-server --port..." → "llama-server"
  ## "/usr/local/bin/mlx_lm.server --model..." → "mlx_lm.server"
  let first = cmd.strip().split(' ', maxsplit = 1)[0]
  if first.len == 0: return "?"
  result = first.extractFilename()
  if result.len == 0: result = first

proc run*(
    model = "",
    schema = "",
    promptFile = "",
    systemPromptFile = "",
    baseUrl = DefaultBaseUrl,
    temperature = DefaultTemperature,
    maxTokens = DefaultMaxTokens,
    timeoutSecs = DefaultTimeoutSecs,
    schemaName = "Response",
    prompt: seq[string] = @[],
) =
  ## One-shot chat-completion against an OpenAI-compatible local server.
  if model.len == 0:
    die("--model is required (e.g. -m Qwen3.6-35B-A3B)")

  # `systemPromptFile` is an alias for `promptFile`, matching the `llm`
  # CLI's `-s/--systemPromptFile` flag. If both supplied, the alias wins.
  let promptValue =
    if systemPromptFile.len > 0: systemPromptFile
    else: promptFile
  let systemPath = resolveResource(promptValue, "prompts", ".md")
  let schemaPath = resolveResource(schema, "schemas", ".schema.json")

  let systemContent =
    if systemPath.len > 0: readFile(systemPath)
    else: ""

  # User content: positional args joined with spaces, plus stdin appended
  # when piped. Matches the `llm` CLI convention.
  var userParts: seq[string] = @[]
  if prompt.len > 0:
    userParts.add(prompt.join(" "))
  if not stdin.isatty:
    let piped = stdin.readAll
    if piped.len > 0:
      userParts.add(piped)
  let userContent = userParts.join("\n").strip()
  if userContent.len == 0:
    die("no user prompt provided (pass positional args or pipe via stdin)")

  var messages = newJArray()
  if systemContent.len > 0:
    messages.add(%*{"role": "system", "content": systemContent})
  messages.add(%*{"role": "user", "content": userContent})

  var body = %*{
    "model": model,
    "messages": messages,
    "temperature": temperature,
    "max_tokens": maxTokens,
  }

  if schemaPath.len > 0:
    var schemaNode: JsonNode
    try:
      schemaNode = parseFile(schemaPath)
    except IOError, JsonParsingError:
      die("failed to load schema at " & schemaPath & ": " & getCurrentExceptionMsg())
    body["response_format"] = %*{
      "type": "json_schema",
      "json_schema": {
        "name": schemaName,
        "strict": true,
        "schema": schemaNode,
      },
    }

  let url = joinUrl(baseUrl, "v1/chat/completions")
  let client = newHttpClient(timeout = timeoutSecs * 1000)
  defer:
    client.close()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})

  var resp: Response
  try:
    resp = client.request(url, httpMethod = HttpPost, body = $body)
  except CatchableError as e:
    die("HTTP request to " & url & " failed: " & e.msg)

  let raw = resp.body
  let status = resp.status

  if not status.startsWith("200"):
    try:
      let err = Json.decode(raw, ApiErrorResponse, allowUnknownFields = true)
      if err.error.isSome and err.error.get.message.isSome:
        die(status & ": " & err.error.get.message.get)
    except CatchableError:
      discard
    die(status & ": " & raw)

  var parsed: ChatResponse
  try:
    parsed = Json.decode(raw, ChatResponse, allowUnknownFields = true)
  except CatchableError as e:
    die("failed to decode response: " & e.msg & "\n---\n" & raw)

  if parsed.choices.isNone or parsed.choices.get.len == 0:
    die("response contained no choices:\n" & raw)
  let firstChoice = parsed.choices.get[0]
  if firstChoice.message.isNone or firstChoice.message.get.content.isNone:
    die("response choice had no message content:\n" & raw)

  echo firstChoice.message.get.content.get

proc models*(json = false, baseUrl = DefaultBaseUrl) =
  ## List all models llama-swap exposes via /v1/models. Currently-loaded
  ## models are marked with `▶`; everything else with a leading space.
  ## Pass --json to dump the raw /v1/models response.
  let url = joinUrl(baseUrl, "v1/models")
  let (ok, body, status) = httpGetRaw(url, ListTimeoutSecs)
  if not ok:
    die("GET " & url & " failed: " & status & "\n" & body)

  if json:
    echo body
    return

  var parsed: ModelsResponse
  try:
    parsed = Json.decode(body, ModelsResponse, allowUnknownFields = true)
  except CatchableError as e:
    die("failed to decode /v1/models response: " & e.msg)
  if parsed.data.isNone:
    die("response had no `data` array:\n" & body)

  let runningSet = fetchRunningIds(baseUrl)
  let total = parsed.data.get.len
  let loaded = runningSet.len

  echo "Models on " & baseUrl & " (" & $total & " total, " &
    $loaded & " currently loaded)"
  echo ""
  for m in parsed.data.get:
    let id = m.id.get("(no id)")
    let marker = if id in runningSet: "▶" else: " "
    var line = marker & " " & id
    if m.name.isSome and m.name.get.len > 0:
      line &= "  (" & m.name.get & ")"
    echo line
    if m.description.isSome and m.description.get.len > 0:
      echo "    " & m.description.get
    if m.aliases.isSome and m.aliases.get.len > 0:
      echo "    aliases: " & m.aliases.get.join(", ")

proc runningCmd*(json = false, baseUrl = DefaultBaseUrl) =
  ## Show currently-loaded models with state, backend, proxy URL, and TTL.
  ## Pass --json to dump the raw /running response.
  ##
  ## Named `runningCmd` to dodge an ambiguity with std/typedthreads.running
  ## that cligen pulls in; the user-facing subcommand stays `running`
  ## via `cmdName=` below.
  let url = joinUrl(baseUrl, "running")
  let (ok, body, status) = httpGetRaw(url, ListTimeoutSecs)
  if not ok:
    die("GET " & url & " failed: " & status & "\n" & body)

  if json:
    echo body
    return

  var parsed: RunningResponse
  try:
    parsed = Json.decode(body, RunningResponse, allowUnknownFields = true)
  except CatchableError as e:
    die("failed to decode /running response: " & e.msg)

  if parsed.running.isNone or parsed.running.get.len == 0:
    echo "(no models currently loaded)"
    return

  for r in parsed.running.get:
    echo r.model.get("?")
    echo "  state    " & r.state.get("?")
    echo "  backend  " & backendFromCmd(r.cmd.get(""))
    echo "  proxy    " & r.proxy.get("?")
    if r.ttl.isSome and r.ttl.get > 0:
      echo "  ttl      " & $r.ttl.get & "s"
    if r.name.isSome and r.name.get.len > 0:
      echo "  name     " & r.name.get
    if r.description.isSome and r.description.get.len > 0:
      echo "  desc     " & r.description.get
    echo ""

when isMainModule:
  import cligen
  dispatchMulti(
    [
      run,
      short = {"model": 'm', "systemPromptFile": 's'},
      help = {
        "model":
          "model name as exposed by the local server (required, e.g. Qwen3.6-35B-A3B)",
        "schema":
          "JSON Schema for structured output; bare name resolves in ~/.config/llm/schemas",
        "promptFile":
          "system-prompt file; bare name resolves in ~/.config/llm/prompts",
        "systemPromptFile":
          "alias for --promptFile, matches the `llm` CLI's -s/--systemPromptFile",
        "baseUrl": "llama-swap server root (no /v1 suffix)",
        "temperature": "sampling temperature",
        "maxTokens": "completion-token cap",
        "timeoutSecs": "HTTP timeout for the whole request",
        "schemaName":
          "value sent as response_format.json_schema.name (label only)",
      },
    ],
    [
      models,
      help = {
        "json": "dump the raw /v1/models response instead of the table",
        "baseUrl": "llama-swap server root (no /v1 suffix)",
      },
    ],
    [
      runningCmd,
      cmdName = "running",
      help = {
        "json": "dump the raw /running response instead of the table",
        "baseUrl": "llama-swap server root (no /v1 suffix)",
      },
    ],
  )
