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
##   load     — force a model to load via /upstream/<model>/health (llama-swap
##              has no native preload endpoint; the proxy ping blocks until the
##              cold-load finishes, so it doubles as a wait-until-ready barrier)
##   unload   — stop one model (POST /api/models/unload/<model>) or every
##              running model (--all → GET /unload)
##
## Resolution and prompt-role semantics for `run` match the `llm` CLI exactly:
##   --promptFile       USER prompt loaded from a file; joined ahead of the
##                      positional prompt and piped stdin. A bare name resolves
##                      under ~/.config/llm/prompts with .md / .txt appended.
##   --systemPromptFile SYSTEM prompt (role:system); a literal path, no dir
##                      resolution — same as `llm`'s `-s`.
##   --schema           JSON Schema for structured output; a bare name resolves
##                      under ~/.config/llm/schemas with .json / .schema.json.
##   --image            image file attached as an OpenAI `image_url` data URI
##                      (base64), repeatable. Needs an mmproj/vision model on
##                      the server side; the user message `content` becomes a
##                      `[{type:text}, {type:image_url}...]` array.
## For all of the above, a value resolves relative to cwd first, then under the
## install dir; both can take inner `/` to traverse subdirectories.
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

import std/[base64, httpclient, os, sets, strutils, terminal, times]
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
  PromptExts = ["", ".md", ".txt"]
  SchemaExts = ["", ".json", ".schema.json"]

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

proc resolveUnder(value, subdir: string, exts: openArray[string]): string =
  ## Resolve a `--schema` / `--promptFile` reference, matching the `llm` CLI's
  ## `resolveUnder`: try `value` (relative to cwd) and
  ## `~/.config/llm/<subdir>/value`, each with every ext in `exts` appended.
  ## First hit wins; "" when nothing matches (the caller emits the error). A
  ## path or filename works as given; a bare name resolves against the install
  ## dir. `exts` must include "" for the as-given case.
  if value.len == 0:
    return ""
  for base in [value, getHomeDir() / ConfigSubpath / subdir / value]:
    for ext in exts:
      let candidate = base & ext
      if fileExists(candidate):
        return candidate
  ""

proc mimeForImage(path: string): string =
  ## Best-effort MIME from the file extension for the data URI. Unknown
  ## extensions fall back to a generic type and let llama-server's mmproj
  ## loader sniff the bytes.
  case path.splitFile.ext.toLowerAscii
  of ".png": "image/png"
  of ".jpg", ".jpeg": "image/jpeg"
  of ".webp": "image/webp"
  of ".gif": "image/gif"
  of ".bmp": "image/bmp"
  else: "application/octet-stream"

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

proc httpPostRaw(url: string, timeoutSecs: int, body = ""): HttpResult =
  ## POST counterpart to httpGetRaw. The unload routes take no body; the empty
  ## default still sends the JSON content-type llama-swap's handlers expect.
  let client = newHttpClient(timeout = timeoutSecs * 1000)
  defer:
    client.close()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})
  try:
    let resp = client.request(url, httpMethod = HttpPost, body = body)
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
    image: seq[string] = @[],
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

  # Resolution + prompt roles match the `llm` CLI exactly (see module doc):
  #   --promptFile       → USER prompt (bare name resolves under prompts/)
  #   --systemPromptFile → SYSTEM prompt (literal path, no dir resolution)
  #   --schema           → bare name resolves under schemas/
  let schemaPath = resolveUnder(schema, "schemas", SchemaExts)
  if schema.len > 0 and schemaPath.len == 0:
    die(
      "schema not found: " & schema & " (looked relative to cwd and in ~/" &
        ConfigSubpath & "/schemas, with optional .json / .schema.json)"
    )

  let promptPath = resolveUnder(promptFile, "prompts", PromptExts)
  if promptFile.len > 0 and promptPath.len == 0:
    die(
      "prompt file not found: " & promptFile & " (looked relative to cwd and in ~/" &
        ConfigSubpath & "/prompts, with optional .md / .txt)"
    )

  if systemPromptFile.len > 0 and not fileExists(systemPromptFile):
    die("system prompt file not found: " & systemPromptFile)

  for img in image:
    if not fileExists(img):
      die("image file not found: " & img)

  let systemContent =
    if systemPromptFile.len > 0: readFile(systemPromptFile)
    else: ""

  # User text: --promptFile contents first (matching `llm`'s "file before
  # positional"), then positional args, then piped stdin. Joined by blank
  # lines; empty pieces dropped.
  var userParts: seq[string] = @[]
  if promptPath.len > 0:
    userParts.add(readFile(promptPath).strip())
  if prompt.len > 0:
    userParts.add(prompt.join(" ").strip())
  if not stdin.isatty:
    let piped = stdin.readAll
    if piped.len > 0:
      userParts.add(piped.strip())
  let userText = userParts.join("\n\n").strip()

  if userText.len == 0 and image.len == 0:
    die(
      "no user prompt provided (pass positional args, --promptFile, " &
        "-i/--image, or pipe via stdin)"
    )

  # User message content: a plain string when there are no images, or an
  # OpenAI content-part array [text?, image_url...] when there are. llama-server
  # honors data-URI image_url parts against an mmproj-equipped model (verified).
  var userContent: JsonNode
  if image.len > 0:
    var parts = newJArray()
    if userText.len > 0:
      parts.add(%*{"type": "text", "text": userText})
    for img in image:
      let dataUri =
        "data:" & mimeForImage(img) & ";base64," & base64.encode(readFile(img))
      parts.add(%*{"type": "image_url", "image_url": {"url": dataUri}})
    userContent = parts
  else:
    userContent = %userText

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

proc stateOf(baseUrl, model: string): string =
  ## Best-effort current state of `model` from /running; "?" if unreachable or
  ## the model isn't listed (e.g. already evicted).
  result = "?"
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
    if r.model.isSome and r.model.get == model:
      return r.state.get("?")

proc load*(baseUrl = DefaultBaseUrl, timeoutSecs = 300, model: seq[string] = @[]) =
  ## Force one or more models to load. llama-swap exposes no preload route, so
  ## we proxy a /health ping through /upstream/<model>, which swaps the model in
  ## and holds the request open until it is ready — making the GET both the
  ## trigger and the wait-until-ready barrier. Each model is loaded in turn.
  if model.len == 0:
    die("at least one model is required (e.g. llm-local load Qwen3.6-35B-A3B)")
  for m in model:
    let url = joinUrl(baseUrl, "upstream/" & m & "/health")
    let started = epochTime()
    let (ok, body, status) = httpGetRaw(url, timeoutSecs)
    let elapsed = epochTime() - started
    if not ok:
      die("load " & m & " failed: " & status & "\n" & body)
    echo "▶ " & m & "  loaded in " & formatFloat(elapsed, ffDecimal, 1) &
      "s  (state: " & stateOf(baseUrl, m) & ")"

proc unload*(all = false, baseUrl = DefaultBaseUrl, model: seq[string] = @[]) =
  ## Stop running models. `--all` stops every process (GET /unload); otherwise
  ## each named model is unloaded via POST /api/models/unload/<model>. Models
  ## reload on their next request, so this only frees memory — it is not
  ## destructive to anything but the in-flight resident state.
  if all:
    if model.len > 0:
      die("--all unloads everything; don't also pass model names")
    let (ok, body, status) = httpGetRaw(joinUrl(baseUrl, "unload"), ListTimeoutSecs)
    if not ok:
      die("unload --all failed: " & status & "\n" & body)
    echo "unloaded all models"
    return
  if model.len == 0:
    die("pass model name(s) to unload, or --all to unload every running model")
  for m in model:
    let url = joinUrl(baseUrl, "api/models/unload/" & m)
    let (ok, body, status) = httpPostRaw(url, ListTimeoutSecs)
    if not ok:
      die("unload " & m & " failed: " & status & "\n" & body)
    echo "unloaded " & m

when isMainModule:
  import cligen
  dispatchMulti(
    [
      run,
      positional = "prompt",
      short = {"model": 'm', "systemPromptFile": 's', "image": 'i'},
      help = {
        "model":
          "model name as exposed by the local server (required, e.g. Qwen3.6-35B-A3B)",
        "schema":
          "JSON Schema for structured output; bare name resolves in ~/.config/llm/schemas",
        "promptFile":
          "USER prompt from a file; bare name resolves in ~/.config/llm/prompts (matches the `llm` CLI)",
        "systemPromptFile":
          "SYSTEM prompt (role:system) from a literal file path; matches the `llm` CLI's -s",
        "image":
          "image file attached as an OpenAI image_url data URI, repeatable (needs an mmproj/vision model)",
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
    [
      load,
      positional = "model",
      help = {
        "baseUrl": "llama-swap server root (no /v1 suffix)",
        "timeoutSecs":
          "max seconds to wait for the cold-load (the proxy ping blocks until ready)",
      },
    ],
    [
      unload,
      positional = "model",
      help = {
        "all": "unload every running model (GET /unload) instead of named ones",
        "baseUrl": "llama-swap server root (no /v1 suffix)",
      },
    ],
  )
