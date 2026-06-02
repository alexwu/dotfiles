---
name: gemini-image-prompting
description: Use when writing or improving prompts for Gemini "Nano Banana" image models (gemini-3.1-flash-image / gemini-3-pro-image, the `banana` CLI) — generating images from text, editing an existing image, composing from reference images, or keeping a subject, character, pose, or style consistent across multiple generated images.
---

# Prompting Gemini Image Models (Nano Banana)

How to get what you want out of `gemini-3.1-flash-image` (flash) and
`gemini-3-pro-image` (pro). To actually run these prompts, see the **banana** skill
(the CLI wrapper). This skill is about the *words and the reference images*, not the flags.

## The one principle

**Describe the scene, don't list keywords.** These models have deep language
understanding — a narrative, descriptive paragraph beats a pile of comma-separated
tags every time. Write like you're briefing a photographer or illustrator, not
tagging a stock photo.

❌ `girl, blonde, crop top, bedroom, anime, 4k, masterpiece`
✅ `A 28-year-old woman with shoulder-length blonde hair sits cross-legged on a
bed by a sunlit window, wearing a soft cream crop top, laughing at something
off-camera. Warm afternoon light, shallow depth of field, modern anime style.`

## Working with reference images (the main event)

You can pass **up to 14 images** as references and describe what to do with them.
This is how you hold a subject / pose / style steady across many generations.

| Model | High-fidelity objects | Character consistency |
|---|---|---|
| `flash` (gemini-3.1-flash-image) | up to 10 | up to 4 characters |
| `pro` (gemini-3-pro-image) | up to 6 | up to 5 characters |

**Refer to images by position in your prompt.** The model sees them in order:
- "Use the **woman from the first image**, in the **pose from the second image**, rendered in the **art style of the third image**."
- "Keep her face, hair, and features from image 1 **completely unchanged**; only change the outfit to the dress in image 2."

**For subject/character consistency across a set:**
1. Generate (or supply) one strong "hero" image of the subject.
2. Pass it as a reference on every subsequent prompt, changing only pose/setting/outfit.
3. Accumulate 2–4 good references from different angles — more angles = a more locked identity.
4. For a turnaround, request **one new angle per call**, always passing the prior angles back as references.

**Preserve critical detail explicitly.** To keep a face or logo intact through an
edit, *describe it in detail in words* alongside the edit instruction — don't rely
on the reference alone: "Ensure the woman's face, freckles, and green eyes remain
exactly as in the reference; only add the jacket."

Text alone drifts; **reference images + explicit "keep X unchanged" wording** is
what actually holds identity.

## Best practices

- **Be hyper-specific.** "ornate elven plate armor etched with silver leaf, high collar, falcon-wing pauldrons" >> "fantasy armor".
- **State intent / purpose.** "a logo for a high-end minimalist skincare brand" beats "a logo" — context steers the result.
- **Iterate conversationally.** Don't expect perfection in one shot. Re-prompt with the last output as a reference: "same image, but warmer lighting" / "keep everything, change her expression to a soft smile".
- **Step-by-step for complex scenes.** "First a misty forest at dawn. Then a moss-covered stone altar in the foreground. Finally a single glowing sword resting on it."
- **Semantic negatives, not "no X".** Instead of "no cars", say "a deserted, empty street". Describe the scene you want positively.
- **Control the camera.** `85mm portrait lens`, `wide-angle`, `macro`, `low-angle`, `golden hour`, `softbox three-point lighting`, `bokeh`.
- **Text in images:** decide the exact text first, describe the font *descriptively* ("clean bold sans-serif"), and use `pro` for the cleanest rendering.

## Recipe catalog

Full prompt patterns with worked examples — photorealistic portraits, stickers/icons,
accurate text, product mockups, negative space, sequential art, style transfer,
inpainting (semantic masking), multi-image composition, high-fidelity preservation,
sketch-to-photo, and character turnarounds — live in
[references/recipes.md](references/recipes.md). Read it when you need a concrete template.

## Quick reference

| Want | Do |
|---|---|
| Realism | photography language: lens, lighting, angle, depth of field |
| A sticker/icon | name the style, request a **white** background (transparent is unsupported) |
| Legible text | spell out the exact words, describe the font, prefer `pro` |
| Edit one region | name what changes AND say "keep the rest unchanged" (semantic masking) |
| Same character, new pose | reference image(s) + "keep face/features from image 1" + new pose |
| Combine subjects | "take the X from image 1 and the Y from image 2…" |

## Limitations (know these going in)

- **No transparent backgrounds** — ask for a solid (white) background instead.
- **Generate text, then the image** — if a scene needs specific text, settle the wording first; the model renders supplied text far better than invented text.
- **No image-search on real people** — identity must come from your prompt text + the reference images you pass, not Google image search.
- **Safety filters refuse explicit/sexual content** — the request returns no image (a block reason). Keep prompts SFW or they fail upstream; there's no flag to bypass it.
- **Best in English** (plus ~14 other well-supported languages); other languages degrade.
- An optional canonical text description of a recurring subject can live in a private file (e.g. `~/.config/llm/luna-character.md`) and be pasted into prompts — but **image references win over text** for consistency.

## Model choice

- **`flash`** — the default. Fast, 512/1K/2K/4K, controllable thinking, web + image-search grounding. Use for most work and high-volume iteration.
- **`pro`** — professional asset production: complex multi-element instructions, the cleanest text rendering, top fidelity. Always "thinks". 1K/2K/4K. Use when flash isn't precise enough.
