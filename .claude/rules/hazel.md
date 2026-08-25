---
paths:
  - "scripts/hazel/**"
---

# Hazel Tools

Nim CLIs in `scripts/hazel/` (source-only, ignored by chezmoi; binaries compile to
`~/.local/bin/` via `run_onchange_build-scripts.sh.tmpl`). Designed to be invoked
per-file from a [Hazel](https://www.noodlesoft.com/) rule, but all run manually too.

## Hazel environment gotcha (bit us once)
Hazel (and launchd) invoke embedded scripts with a **minimal PATH** that omits
`~/.local/bin` — where `llm-local`, `gif-mosaic`, etc. live. Every hazel tool that
shells out to another `~/.local/bin` binary must self-prepend it:
```nim
putEnv("PATH", getHomeDir() / ".local" / "bin" & ":" & getEnv("PATH"))
```
Converting `heic-ai-rename` from `pi` (a mise shim already on PATH) to `llm-local`
broke it silently because of this — a local-shell test passed only because the dev
shell *had* `~/.local/bin`. Test hazel tools under the real minimal env:
`env -i HOME=$HOME PATH=/opt/homebrew/bin:/usr/bin:/bin <tool> …`.

## Tools

- `scripts/hazel/heic_ai_rename.nim` (binary `heic-ai-rename`) — convert an image to
  PNG and rename it via `llm-local` vision, then move it into a destination folder.
  `heic-ai-rename <input> <context-hint> <dest-folder> [model]`. HEIC/HEIF/JPEG →
  PNG via `sips`; the `<context-hint>` biases the model toward a more specific
  kebab-case filename (~40 chars, 60 max). Default model `Qwen3.6-35B-A3B-heretic`
  (always-on = no cold-load, uncensored = won't refuse NSFW). Original is trashed
  (`trash` CLI) or deleted on success.

- `scripts/hazel/image_sort.nim` (binary `image-sort`) — classify a Downloads image
  as `lulu | skyrim | screenshot | meme | wallpaper | other` via `llm-local`
  structured output, then rename +
  route it under a sorted tree. `image-sort [--dry-run|-n] [-m|--model <id>] <input> [root]`.
  Root defaults to `~/Media/Images` — deliberately OUTSIDE `~/Downloads` (change the
  ONE path to relocate the whole local library; an encrypted archive like a
  Cryptomator/BombeeCloud vault is synced separately). Routing:
  `lulu → Lulu/<style>/<name>.png` (nsfw → `…/nsfw/`),
  `skyrim → Skyrim/<name>.png` (nsfw → `…/nsfw/`),
  `screenshot → Screenshots/<name>.png`, `meme → Memes/<name>.png`,
  `wallpaper → Wallpapers/<name>.png` (nsfw → `…/nsfw/`),
  `other → Other/<original-name>` (verbatim, no rename). Accepts HEIC/HEIF/JPG/JPEG/PNG/WEBP/**AVIF**/**SVG**/GIF + short
  **videos** (MP4/MOV/M4V/WEBM/MKV). Each normalizes to a working PNG *only to
  classify*, by kind: raster (heic/jpg/webp/avif/static-gif) → `sips`; `svg` →
  `resvg` (pure-Rust rasterizer, brew dep); animated gif / video → a `gif-mosaic`
  contact sheet (whole-animation view, not frame 1). **GIF / SVG / video keep their
  ORIGINAL file** (animation / vector / clip preserved — the working PNG was just a
  proxy); other raster lands as the converted `.png` and the original is trashed.
  - **Videos go through gif-mosaic WITHOUT `--force`**, so its 200 MB / 5 min guard
    rejects a full-length movie — which image-sort then **skips** (exit 0, file
    untouched) rather than misfiling a feature film. Any unsupported extension is
    likewise skipped with exit 0, never a hard `fail` — a `fail` would surface as
    "Shell script failed" in Hazel and leave the file to be retried (the wrong
    signal for "not my job"). `skip` vs `fail` is the deliberate split.
  - Schema `image-sort` + prompt `image-sort` (both under `~/.config/llm`,
    deliberately **uncommitted** — they carry reference-subject appearance text kept
    out of this public repo). `skyrim` **is** a schema category (added to the enum),
    and the rule that maps a source domain to it lives in the **prompt** — the model
    makes the call from the DOWNLOAD SOURCE hint. There is deliberately **no**
    hardcoded host match in the Nim (an earlier draft did that; ripped out so all
    classification logic sits in one place — the schema + prompt).
  - **"Where from" provenance** (`com.apple.metadata:kMDItemWhereFroms` — the source
    URL a browser stamps on a download) is read straight from the xattr bytes, NOT
    via `mdls`, which lags the Spotlight index on a just-downloaded file (so it works
    before Spotlight catches up, AND the library can be added to Spotlight Privacy
    without blinding the tool). It's appended to the classify call as a **DOWNLOAD
    SOURCE** hint, which the prompt uses two ways: to route a `nexusmods.com` /
    `loverslab.com` download to the `skyrim` category (the source rule wins over the
    visual categories; prompt carries a `NOTE` on tightening to the Nexus game id —
    `/mods/1704/` = Skyrim SE — if non-Skyrim Nexus images leak in), and to sharpen
    naming for everything else. When a raster is sips-converted (heic/jpg/webp/avif)
    the fresh PNG would lose the xattr, so it's re-stamped byte-exact (`xattr -px` →
    `-wx`) onto the converted file before the original is trashed. New deps: `xattr`
    + `plutil` (macOS built-ins in `/usr/bin`, already on the Hazel rule's PATH).
  - **NOTE(alexwu):** root now defaults to `~/Media/Images`, OUTSIDE `~/Downloads`,
    so a Hazel rule watching Downloads never re-processes its own sorted output. The
    Hazel rule invokes `image-sort "$1"` with NO root arg, so it rides this default —
    relocating the library is a one-line `defaultRootRel` change, no Hazel edit. Only
    if `<root>` is ever pointed back INSIDE the watched Downloads tree must the rule
    be scoped to the top level, or it loops on its own `Images/`.

- `scripts/hazel/gif_mosaic.nim` (binary `gif-mosaic`) — render an animation (gif,
  animated webp, short video — anything ffmpeg reads) into a single contact-sheet
  PNG so a viewer that can't see motion (an LLM agent) takes in the whole animation
  at once. `gif-mosaic [--force] [--output PATH] [--cells N] [--aspect W:H]
  [--cell-width PX] <input>`. Prints the mosaic path to stdout (temp file unless
  `--output`). Pure ffmpeg/ffprobe — no ImageMagick.
  - **Sampling** is timestamp-based: each frame at the midpoint of one of N equal
    time-slices → coverage spans the WHOLE animation, not the first ~80% a
    frame-interval gives. `extractFrame` backs off in half-slice steps if a sample
    overshoots the final frame's PTS (gif input-seek overshoots into the
    post-final-frame gap — likelier the more cells you sample), so a loose
    container duration can't abort the whole mosaic.
  - **`--aspect` is authoritative; `--cells` is a target.** The grid is shaped to
    the requested ratio (`rows = √(cells/r)`, `cols = rows·r`) and the realized
    frame count is `cols·rows`. Forcing `cols·rows == cells` exactly collapses every
    ratio to the same grid at low counts (12 only factors as 4×3 / 6×2), so the
    aspect flag would silently do nothing — letting the count flex is what makes the
    shape actually change.
  - **`--cell-width` default 400 is the bang-for-buck knee.** Verified empirically:
    a vision model resizes a large mosaic down to a fixed input budget (~1500-2000px
    long edge) before looking, so `cols·400 ≈ 1600` for the default 4 cols lands on
    that budget. 720px (2880px wide) read *identically* to 480 — double the bytes,
    zero extra clarity. 200px was genuinely too fuzzy. Raise it only for a **human**
    eyeballing the PNG (no downscaling); it's wasted on an LLM consumer.
  - **Guard:** refuses inputs over 200 MB or ~5 min unless `--force` — so a stray
    movie can't grind it. Even forced, it only ever samples `--cells` frames.

## Shared conventions
- All three run `llm-local` (not the upstream `llm` CLI) for vision — direct POST to
  llama-swap's OpenAI endpoint, no per-call process spawn. See `claude-scripts.md`
  for `llm-local`'s flags and `llm-local.md` for structured-output enforcement.
- A `run()` helper closes the child's stdin immediately (EOF) so `llm-local`/`xh`
  don't block reading a body that never arrives in a non-TTY context, and drains
  stderr separately to avoid a full-pipe deadlock.
