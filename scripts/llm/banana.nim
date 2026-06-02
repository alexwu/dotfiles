## banana — a small CLI over Gemini's "Nano Banana" native image models
## (https://ai.google.dev/gemini-api/docs/image-generation). Generate images
## from text, edit/compose from input images, and mix up to 14 reference images
## to hold a subject / style consistent across poses.
##
## Subcommands:
##   banana generate <prompt...> [-r ref]...        text-to-image (+ optional refs)
##   banana edit -i img [-i img]... <prompt...>     image(s)+text-to-image (edit/compose)
##   banana models                                  list models, aliases, ratios, sizes
##
## Models (--model, default `flash`):
##   flash → gemini-3.1-flash-image  (Nano Banana 2)   512/1K/2K/4K, fast, thinking minimal|high
##   pro   → gemini-3-pro-image      (Nano Banana Pro)  1K/2K/4K, always-thinking, top fidelity/text
##   2.5   → gemini-2.5-flash-image  (Nano Banana)      1K only, legacy
## Any other --model value is passed through as a raw model id.
##
## Auth: reads $GEMINI_API_KEY. Never logs the key. `--dry-run` builds and prints
## the request (image data elided) WITHOUT calling the API or needing a key.
##
## Output: writes the returned image(s) — JPEG by default (these models return
## image/jpeg; the extension follows the response MIME type) — and prints each
## path to stdout. With no --output, names the file from a slug of the prompt in
## the cwd, suffixing -2, -3 on collision.
##
## NOTE(alexwu): the REST aspect-ratio/size field is documented inconsistently
## upstream (every curl example uses generationConfig.responseFormat.image.* but
## the SDKs use imageConfig). This mirrors the curl examples. `--api-version`
## (default v1beta — v1 rejects the image-gen config fields) is overridable.

import std/[base64, json, options, os, osproc, strutils]
import std/httpclient
import json_serialization
import json_serialization/std/options as jsOptions
import cligen

const
  apiBase = "https://generativelanguage.googleapis.com"
    # v1beta: the stable v1 GenerationConfig proto rejects responseModalities /
    # responseFormat / thinkingConfig ("Cannot find field"); the image-gen
    # config fields only exist on v1beta. Overridable via --api-version.
  defaultApiVersion = "v1beta"

  flashModel = "gemini-3.1-flash-image"
  proModel = "gemini-3-pro-image"
  legacyModel = "gemini-2.5-flash-image"

  maxRefImages = 14
  requestTimeoutMs = 300_000

  validAspects = [
    "1:1", "1:4", "1:8", "2:3", "3:2", "3:4", "4:1", "4:3", "4:5", "5:4", "8:1", "9:16",
    "16:9", "21:9",
  ]
  validSizes = ["512", "1K", "2K", "4K"]
  # The flash image model documents only minimal|high (the generic ThinkingConfig
  # proto also has low|medium, but the image model doesn't honor them).
  validThinking = ["minimal", "high"]
  # Extreme ratios are a 3.1-Flash addition; the pro and 2.5 tables omit them.
  flashOnlyAspects = ["1:4", "4:1", "1:8", "8:1"]

type
  GeminiBlob = object
    data: Option[string]
    mimeType: Option[string]

  GeminiPart = object
    text: Option[string]
    inlineData: Option[GeminiBlob]
    thought: Option[bool]

  GeminiContent = object
    parts: Option[seq[GeminiPart]]

  GeminiCandidate = object
    content: Option[GeminiContent]
    finishReason: Option[string]

  GeminiErrorObj = object
    code: Option[int]
    message: Option[string]
    status: Option[string]

  GeminiPromptFeedback = object
    blockReason: Option[string]

  GeminiResponse = object
    ## Decoded API response. Every field Option[T] so a malformed/short body
    ## surfaces as None at decode time rather than a silent zero-value (per the
    ## repo's json_serialization convention).
    candidates: Option[seq[GeminiCandidate]]
    promptFeedback: Option[GeminiPromptFeedback]
    error: Option[GeminiErrorObj]

proc fail(msg: string) {.noreturn.} =
  stderr.writeLine "banana: " & msg
  quit(1)

func resolveModel(m: string): string =
  ## Friendly alias → model id. Unknown values pass through as a raw id.
  case m.toLowerAscii()
  of "flash", "3.1-flash", "3.1flash", "nano-banana-2", "nb2": flashModel
  of "pro", "3-pro", "3pro", "nano-banana-pro", "nbpro": proModel
  of "2.5", "2.5-flash", "legacy", "nano-banana", "nb": legacyModel
  else: m

func aspectEnum(a: string): string =
  ## Friendly ratio → v1beta ImageResponseFormat.AspectRatio enum.
  case a
  of "1:1": "ASPECT_RATIO_ONE_BY_ONE"
  of "2:3": "ASPECT_RATIO_TWO_BY_THREE"
  of "3:2": "ASPECT_RATIO_THREE_BY_TWO"
  of "3:4": "ASPECT_RATIO_THREE_BY_FOUR"
  of "4:3": "ASPECT_RATIO_FOUR_BY_THREE"
  of "4:5": "ASPECT_RATIO_FOUR_BY_FIVE"
  of "5:4": "ASPECT_RATIO_FIVE_BY_FOUR"
  of "9:16": "ASPECT_RATIO_NINE_BY_SIXTEEN"
  of "16:9": "ASPECT_RATIO_SIXTEEN_BY_NINE"
  of "21:9": "ASPECT_RATIO_TWENTY_ONE_BY_NINE"
  of "1:8": "ASPECT_RATIO_ONE_BY_EIGHT"
  of "8:1": "ASPECT_RATIO_EIGHT_BY_ONE"
  of "1:4": "ASPECT_RATIO_ONE_BY_FOUR"
  of "4:1": "ASPECT_RATIO_FOUR_BY_ONE"
  else: ""

func sizeEnum(s: string): string =
  ## Friendly size → v1beta ImageResponseFormat.ImageSize enum.
  case s
  of "512": "IMAGE_SIZE_FIVE_TWELVE"
  of "1K": "IMAGE_SIZE_ONE_K"
  of "2K": "IMAGE_SIZE_TWO_K"
  of "4K": "IMAGE_SIZE_FOUR_K"
  else: ""

func thinkingEnum(t: string): string =
  ## Friendly level → v1beta ThinkingConfig.thinkingLevel enum.
  t.toUpperAscii()

func extFor(mime: string): string =
  ## Output extension from a response blob's MIME type. These models return
  ## JPEG by default, so honoring the actual type avoids a .png that holds JPEG.
  case mime.toLowerAscii()
  of "image/png": ".png"
  of "image/jpeg", "image/jpg": ".jpg"
  of "image/webp": ".webp"
  else: ".png"

func mimeFor(path: string): string =
  ## MIME type from extension, or "" for an unsupported type.
  case path.splitFile().ext.toLowerAscii()
  of ".png": "image/png"
  of ".jpg", ".jpeg": "image/jpeg"
  of ".webp": "image/webp"
  of ".gif": "image/gif"
  of ".heic": "image/heic"
  of ".heif": "image/heif"
  of ".avif": "image/avif"
  else: ""

func slugify(raw: string): string =
  ## Lowercase, collapse runs of non-alnum to a single `-`, trim dashes, and
  ## clamp to ~60 chars on a word boundary.
  result = newStringOfCap(raw.len)
  var prevDash = true
  for ch in raw.toLowerAscii():
    if ch in {'a' .. 'z', '0' .. '9'}:
      result.add ch
      prevDash = false
    elif not prevDash:
      result.add '-'
      prevDash = true
  if result.len > 0 and result[^1] == '-':
    result.setLen(result.len - 1)
  if result.len > 60:
    result.setLen(60)
    let lastDash = result.rfind('-')
    if lastDash > 30:
      result.setLen(lastDash)
    result = result.strip(chars = {'-'})

proc uniquePath(dir, base, ext: string): string =
  result = dir / (base & ext)
  var i = 2
  while fileExists(result):
    result = dir / (base & "-" & $i & ext)
    inc i

proc convertTo(path, fmt: string): string =
  ## Convert a saved image to `fmt` (png|webp), drop the original JPEG, and return
  ## the new path. The API only ever emits JPEG, so this is a local re-encode:
  ## `sips` for png (no extra dep), `magick` for webp (sips can't write webp).
  result = path.changeFileExt(fmt)
  let tool =
    case fmt
    of "png":
      "sips"
    of "webp":
      "magick"
    else:
      fail("unsupported convert format: " & fmt)
  let args =
    if fmt == "png":
      @["-s", "format", "png", path, "--out", result]
    else:
      @[path, result]
  discard execProcess(tool, args = args, options = {poUsePath, poStdErrToStdOut})
  if not fileExists(result):
    fail(
      tool & " conversion to " & fmt & " failed for " & path & " (is " & tool &
        " installed?)"
    )
  if result != path:
    removeFile(path)

proc imagePart(path: string): JsonNode =
  let mime = mimeFor(path)
  if mime.len == 0:
    fail("unsupported image type: " & path & " (png/jpg/webp/gif/heic/heif/avif)")
  if not fileExists(path):
    fail("no such image: " & path)
  let raw = readFile(path)
  result = %*{"inline_data": {"mime_type": mime, "data": encode(raw)}}

proc buildRequest(
    promptText: string,
    images: seq[string],
    aspect, size, thinking: string,
    wantText, search, imageSearch: bool,
): JsonNode =
  var parts = newJArray()
  if promptText.strip().len > 0:
    parts.add %*{"text": promptText}
  for img in images:
    parts.add imagePart(img)

  var genCfg = newJObject()
  genCfg["responseModalities"] =
    if wantText:
      %*["TEXT", "IMAGE"]
    else:
      %*["IMAGE"]
  if aspect.len > 0 or size.len > 0:
    var imgCfg = newJObject()
    if aspect.len > 0:
      imgCfg["aspectRatio"] = %aspectEnum(aspect)
    if size.len > 0:
      imgCfg["imageSize"] = %sizeEnum(size)
    genCfg["responseFormat"] = %*{"image": imgCfg}
  if thinking.len > 0:
    genCfg["thinkingConfig"] = %*{"thinkingLevel": thinkingEnum(thinking)}

  result =
    %*{"contents": [{"role": "user", "parts": parts}], "generationConfig": genCfg}

  if search or imageSearch:
    var gs = newJObject()
    if imageSearch:
      gs["searchTypes"] = %*{"webSearch": newJObject(), "imageSearch": newJObject()}
    result["tools"] = %*[{"google_search": gs}]

func elide(n: JsonNode): JsonNode =
  ## Copy `n` with any base64 `data` string replaced by a short placeholder, so
  ## a dry-run request is readable instead of megabytes of base64.
  case n.kind
  of JObject:
    result = newJObject()
    for k, v in n:
      if k == "data" and v.kind == JString and v.str.len > 48:
        result[k] = %("<" & $v.str.len & " base64 chars elided>")
      else:
        result[k] = elide(v)
  of JArray:
    result = newJArray()
    for item in n:
      result.add elide(item)
  else:
    result = n

proc sendRequest(url, key, body: string): string =
  let client = newHttpClient(timeout = requestTimeoutMs)
  defer:
    client.close()
  client.headers =
    newHttpHeaders({"Content-Type": "application/json", "x-goog-api-key": key})
  try:
    let resp = client.request(url, httpMethod = HttpPost, body = body)
    result = resp.body
  except CatchableError as e:
    fail("request failed: " & e.msg)

proc decodeResponse(body: string): GeminiResponse =
  try:
    result = Json.decode(body, GeminiResponse, allowUnknownFields = true)
  except CatchableError as e:
    fail("could not decode API response: " & e.msg & "\n---\n" & body)

proc resolveOut(outSpec, promptText, mime: string, idx, total: int): string =
  ## Decide where image `idx` of `total` lands. Extension follows the response
  ## MIME type, except an explicit `--output FILE.ext` keeps the user's ext.
  let suffix =
    if total > 1:
      "-" & $(idx + 1)
    else:
      ""
  let ext = extFor(mime)
  let slug = block:
    let s = slugify(promptText)
    if s.len > 0: s else: "banana"
  if outSpec.len == 0:
    result = uniquePath(getCurrentDir(), slug & suffix, ext)
  elif outSpec.endsWith(DirSep) or dirExists(outSpec):
    result =
      uniquePath(outSpec.strip(trailing = true, chars = {DirSep}), slug & suffix, ext)
  else:
    let (dir, base, userExt) = outSpec.splitFile()
    let d =
      if dir.len > 0:
        dir
      else:
        getCurrentDir()
    let useExt = if userExt.len > 0: userExt else: ext
    if total > 1:
      result = uniquePath(d, base & suffix, useExt)
    else:
      result = d / (base & useExt)

proc writeImages(resp: GeminiResponse, outSpec, promptText, body: string): seq[string] =
  if resp.error.isSome:
    let e = resp.error.get
    fail(
      "API error " & $e.code.get(0) & " (" & e.status.get("") & "): " &
        e.message.get("unknown")
    )
  if resp.promptFeedback.isSome and resp.promptFeedback.get.blockReason.isSome:
    fail("prompt blocked by safety filters: " & resp.promptFeedback.get.blockReason.get)
  if resp.candidates.isNone or resp.candidates.get.len == 0:
    fail("no candidates returned\n---\n" & body)

  let cand = resp.candidates.get[0]
  var texts: seq[string]
  var blobs: seq[tuple[mime, data: string]]
  if cand.content.isSome and cand.content.get.parts.isSome:
    for p in cand.content.get.parts.get:
      if p.thought.get(false):
        continue # skip interim "thought" images / reasoning text
      if p.text.isSome and p.text.get.len > 0:
        texts.add p.text.get
      if p.inlineData.isSome and p.inlineData.get.data.isSome:
        blobs.add (
          p.inlineData.get.mimeType.get("image/png"), p.inlineData.get.data.get
        )

  for t in texts:
    stderr.writeLine("banana: " & t)
  if blobs.len == 0:
    fail(
      "no image in response (finishReason: " & cand.finishReason.get("?") & ")\n---\n" &
        body
    )

  for i, blob in blobs:
    let path = resolveOut(outSpec, promptText, blob.mime, i, blobs.len)
    let dir = path.splitFile().dir
    if dir.len > 0:
      createDir(dir)
    writeFile(path, decode(blob.data))
    result.add path

proc generateCore(
    promptText: string,
    images: seq[string],
    model, aspect, size, thinking, outSpec: string,
    text, search, imageSearch, png, webp, dryRun: bool,
    apiVersion: string,
) =
  let resolved = resolveModel(model)
  if png and webp:
    fail("choose one of --png / --webp, not both")
  let convertFmt =
    if png:
      "png"
    elif webp:
      "webp"
    else:
      ""
  if aspect.len > 0 and aspect notin validAspects:
    fail("invalid --aspect '" & aspect & "' (valid: " & validAspects.join(" ") & ")")
  if aspect in flashOnlyAspects and resolved != flashModel:
    fail(
      "--aspect " & aspect & " is flash-only (pro/2.5 support: " &
        "1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9 21:9)"
    )
  if size.len > 0 and size notin validSizes:
    fail("invalid --size '" & size & "' (valid: 512 1K 2K 4K)")
  if size == "512" and resolved != flashModel:
    fail("--size 512 is only supported by the flash model")
  if size in ["2K", "4K"] and resolved == legacyModel:
    fail(
      "--size " & size & " needs a Gemini 3 model (flash/pro); 2.5 generates 1K only"
    )
  if thinking.len > 0 and thinking notin validThinking:
    fail("invalid --thinking '" & thinking & "' (minimal|high)")
  if thinking.len > 0 and resolved != flashModel:
    fail(
      "--thinking only applies to flash (pro always thinks; 2.5 has no thinking knob)"
    )
  if imageSearch and resolved != flashModel:
    fail("--imageSearch (image-search grounding) is only available on the flash model")
  if images.len > maxRefImages:
    fail("too many images: " & $images.len & " (max " & $maxRefImages & ")")
  if promptText.strip().len == 0 and images.len == 0:
    fail("nothing to do: provide a prompt and/or images")

  let req =
    buildRequest(promptText, images, aspect, size, thinking, text, search, imageSearch)
  let url = apiBase & "/" & apiVersion & "/models/" & resolved & ":generateContent"

  if dryRun:
    echo "POST ", url
    echo "model: ", resolved
    echo elide(req).pretty
    return

  let key = getEnv("GEMINI_API_KEY").strip()
  if key.len == 0:
    fail("GEMINI_API_KEY is not set")
  let body = sendRequest(url, key, $req)
  let resp = decodeResponse(body)
  for path in writeImages(resp, outSpec, promptText, body):
    if convertFmt.len > 0:
      echo convertTo(path, convertFmt)
    else:
      echo path

proc generate(
    prompt: seq[string],
    model = "flash",
    aspect = "",
    size = "",
    thinking = "",
    refs: seq[string] = @[],
    output = "",
    text = false,
    search = false,
    imageSearch = false,
    png = false,
    webp = false,
    dryRun = false,
    apiVersion = defaultApiVersion,
) =
  ## Generate an image from a text prompt (text-to-image). Optionally mix in up
  ## to 14 reference images with -r/--refs to steer subject, style, or pose.
  generateCore(
    prompt.join(" "),
    refs,
    model,
    aspect,
    size,
    thinking,
    output,
    text,
    search,
    imageSearch,
    png,
    webp,
    dryRun,
    apiVersion,
  )

proc edit(
    prompt: seq[string],
    image: seq[string] = @[],
    model = "flash",
    aspect = "",
    size = "",
    thinking = "",
    refs: seq[string] = @[],
    output = "",
    text = false,
    search = false,
    imageSearch = false,
    png = false,
    webp = false,
    dryRun = false,
    apiVersion = defaultApiVersion,
) =
  ## Edit / compose from input image(s) + a text instruction. -i/--image is the
  ## image(s) to modify (at least one required); add more -i or -r/--refs for
  ## extra references. Inputs + refs together must not exceed 14.
  if image.len == 0:
    fail("edit needs at least one --image/-i")
  generateCore(
    prompt.join(" "),
    image & refs,
    model,
    aspect,
    size,
    thinking,
    output,
    text,
    search,
    imageSearch,
    png,
    webp,
    dryRun,
    apiVersion,
  )

proc models() =
  ## List available models, their aliases, aspect ratios, and sizes.
  echo """models (pass via --model, default `flash`):
  flash   gemini-3.1-flash-image   Nano Banana 2    512/1K/2K/4K · fast · thinking minimal|high · web+image search
  pro     gemini-3-pro-image       Nano Banana Pro  1K/2K/4K · always-thinking · best fidelity & text
  2.5     gemini-2.5-flash-image   Nano Banana      1K only · legacy

aspect ratios (--aspect): 1:1 1:4 1:8 2:3 3:2 3:4 4:1 4:3 4:5 5:4 8:1 9:16 16:9 21:9
  (pro drops the extremes: no 1:4 4:1 1:8 8:1)
sizes (--size): 512 (flash only) · 1K · 2K · 4K   (uppercase K required)
reference images: up to 14 total (-r/--refs; for edit also -i/--image)"""

when isMainModule:
  clCfg.version = "banana 0.1.0"
  dispatchMulti(
    [
      generate,
      positional = "prompt",
      help = {
        "model": "model or alias: flash|pro|2.5 (or a raw model id)",
        "aspect": "aspect ratio, e.g. 16:9 (see `banana models`)",
        "size": "resolution: 512|1K|2K|4K",
        "thinking": "flash thinking level: minimal|high",
        "refs": "reference image to mix in (repeatable, up to 14)",
        "output": "output file or directory (default: slug of prompt in cwd)",
        "text": "also request and print model text output",
        "search": "enable Google Search grounding",
        "imageSearch": "enable image-search grounding (flash only)",
        "png": "convert the saved JPEG to PNG locally (sips)",
        "webp": "convert the saved JPEG to WebP locally (sips)",
        "dryRun": "build and print the request; do not call the API",
        "apiVersion": "API version path segment (default v1beta)",
      },
      short = {
        "refs": 'r',
        "output": 'o',
        "model": 'm',
        "aspect": 'a',
        "size": 's',
        "dryRun": 'n',
        "imageSearch": 'I',
      },
    ],
    [
      edit,
      positional = "prompt",
      help = {
        "image": "image to edit/compose (repeatable, at least one)",
        "model": "model or alias: flash|pro|2.5 (or a raw model id)",
        "aspect": "aspect ratio, e.g. 16:9 (see `banana models`)",
        "size": "resolution: 512|1K|2K|4K",
        "thinking": "flash thinking level: minimal|high",
        "refs": "extra reference image (repeatable; +images ≤ 14)",
        "output": "output file or directory (default: slug of prompt in cwd)",
        "text": "also request and print model text output",
        "search": "enable Google Search grounding",
        "imageSearch": "enable image-search grounding (flash only)",
        "png": "convert the saved JPEG to PNG locally (sips)",
        "webp": "convert the saved JPEG to WebP locally (sips)",
        "dryRun": "build and print the request; do not call the API",
        "apiVersion": "API version path segment (default v1beta)",
      },
      short = {
        "image": 'i',
        "refs": 'r',
        "output": 'o',
        "model": 'm',
        "aspect": 'a',
        "size": 's',
        "dryRun": 'n',
        "imageSearch": 'I',
      },
    ],
    [models],
  )
