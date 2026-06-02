---
name: banana
description: Use when generating or editing images from the terminal with Google's Gemini "Nano Banana" image models — the `banana` CLI. Triggers on "banana generate", "banana edit", "nano banana", "generate an image", "edit this image with AI", "make a reference image", "image to image", or passing reference images to gemini-3.1-flash-image / gemini-3-pro-image. For how to write the prompt itself, also use the gemini-image-prompting skill.
---

# banana — Gemini image-generation CLI

`banana` wraps Gemini's Nano Banana image API (REST `v1beta`). It builds the
request, base64-encodes inputs, sends it, and writes the returned image(s) to
disk. Source: `scripts/llm/banana.nim`. Auth: reads `$GEMINI_API_KEY`.

**For prompt wording and the reference-image workflow, use the `gemini-image-prompting` skill.** This skill is the command reference.

## Commands

```sh
banana generate <prompt...> [-r ref]...        # text-to-image (+ optional refs)
banana edit -i img [-i img]... <prompt...>     # image(s)+text-to-image (edit/compose)
banana models                                  # list models, aliases, ratios, sizes
```

The prompt is positional (no quotes needed; remaining words are joined).

## Key flags (both generate and edit)

| Flag | Meaning |
|---|---|
| `-m, --model` | `flash` (default), `pro`, `2.5`, or a raw model id |
| `-a, --aspect` | `1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9 21:9` (+ `1:4 4:1 1:8 8:1` on flash) |
| `-s, --size` | `512` (flash only) · `1K` · `2K` · `4K` (default 1K) |
| `-r, --refs` | reference image to mix in (repeatable; up to 14 total) |
| `-o, --output` | output file or directory (default: a slug of the prompt in cwd) |
| `-i, --image` | (edit only) image to modify (repeatable, ≥1 required) |
| `--thinking` | `minimal\|high` (flash only; pro always thinks, 2.5 has no knob) |
| `--text` | also request + print the model's text output (to stderr) |
| `-p, --png` / `-w, --webp` | re-encode the saved JPEG to PNG/WebP locally (png via `sips`, webp via `magick`) |
| `--search` | Google Search grounding; `-I/--imageSearch` adds image search (flash) |
| `-n, --dry-run` | build and print the request; **no API call, no key needed** |

Friendly values (`16:9`, `2K`, `high`) are translated to the API's verbose enums
internally. Run `banana <cmd> --help` for the full list.

## Examples

```sh
# Simple generate (writes ./<slug>.jpg)
banana generate a cozy reading nook with a cat, golden hour --aspect 3:2

# High-quality, pick the model + size + output
banana generate an isometric miniature city, soft PBR materials -m pro -s 4K -o city.png

# Edit an existing image
banana edit add a small knitted wizard hat to the cat -i cat.png

# Compose: same subject across a new pose using reference images
banana generate a studio portrait, profile view, white background \
  -r refs/front.png -r refs/three-quarter.png -o portrait

# Inspect the exact request without spending anything
banana generate test prompt --aspect 16:9 --size 2K --dry-run
```

## Gotchas (verified)

- **Output is JPEG — that's the API's only format.** The models return
  `image/jpeg` (the `ImageResponseFormat.mimeType` enum offers nothing else);
  `banana` names the file from the response MIME (auto-named files end `.jpg`).
  There's no API knob for PNG/WebP — use `--png` / `--webp` to re-encode locally
  after download (`sips` / `magick`).
- **`v1beta`, not `v1`.** The image-gen config fields (`responseModalities`,
  `responseFormat`, `thinkingConfig`) don't exist on stable `v1` — `banana`
  defaults to `v1beta`. `--api-version` overrides it.
- **`GEMINI_API_KEY` must be set** for real calls (dry-run doesn't need it). The
  key is never logged.
- **Reference cap is 14 total** (`-i` + `-r` combined). Per-call identity limits:
  flash = 4 characters / 10 objects, pro = 5 characters / 6 objects.
- **No transparent background, no explicit content** (safety filters refuse and
  return no image), best results in English. See `gemini-image-prompting` limitations.
- **`--size 512` is flash-only**; `banana` rejects it on pro/2.5 before calling.

## Cost note

Each successful call bills image-generation tokens (size/aspect-dependent — see
`banana models` and Google's pricing). Use `--dry-run` to iterate on the request
shape for free; prefer `flash` + smaller `--size` while experimenting.
