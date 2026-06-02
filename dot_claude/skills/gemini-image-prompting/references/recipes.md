# Nano Banana prompt recipes

Concrete, copy-and-adapt templates. Each is a *narrative paragraph* — fill the
bracketed parts and delete what you don't need. All examples are SFW; the safety
filter refuses explicit content regardless of wording.

---

## Generation (text → image)

### Photorealistic scene / portrait
Lead with the shot type, then subject, then setting, then light, then lens.
> A photo of a [close-up portrait] of [subject: an elderly Japanese ceramicist
> with deep, sun-etched wrinkles and a warm smile], [doing: inspecting a freshly
> glazed tea bowl]. The setting is [a rustic sun-drenched workshop]. Illuminated
> by [soft golden-hour light from a side window]. Captured with an [85mm portrait
> lens, shallow depth of field, bokeh background]. Mood: [serene, masterful].
> [Vertical portrait orientation].

### Stylized illustration / sticker / icon
Be explicit about style; request a white background (transparent is unsupported).
> A [kawaii-style] sticker of [a happy red panda wearing a tiny bamboo hat,
> munching a green leaf]. [Bold clean outlines, simple cel-shading, vibrant
> palette]. The background must be white.

### Accurate text in an image (use `pro`)
Settle the exact words first; describe the font descriptively.
> Create a [modern minimalist] logo for [a coffee shop called "The Daily Grind"].
> The text "[The Daily Grind]" is in a [clean bold sans-serif] font. [Black and
> white], inside a circle, with [a coffee bean worked in cleverly].

### Product mockup / commercial
> A high-resolution, studio-lit product photograph of [a matte-black ceramic
> mug] on [a polished concrete surface]. [Three-point softbox lighting, soft
> diffused highlights]. Camera at [a slightly elevated 45° angle]. Ultra-realistic,
> sharp focus on [the rising steam]. Square image.

### Minimalist / negative space (room for overlaid text later)
> A minimalist composition: [a single delicate red maple leaf] in the
> [bottom-right]. The background is [a vast off-white canvas] with significant
> negative space. [Soft diffused light from the top-left]. Square image.

### Sequential art (comic / storyboard)
Works best with `pro` or `flash`; combine with character refs for consistency.
> Make a [3-panel] comic in [a gritty noir style, high-contrast black-and-white
> inks]. [Put the character from the reference image into a humorous scene where …].

---

## Editing & composition (image + text → image)

### Add / remove an element
Provide the image; the model matches its existing style, lighting, perspective.
> Using the provided image of [my cat], [add a small knitted wizard hat on its
> head]. Make it sit naturally and match the soft lighting of the photo.

### Inpainting (semantic masking) — change one region, keep the rest
> Using the provided image of [a living room], change only [the blue sofa] to
> [a vintage brown leather chesterfield]. Keep [the pillows, the rug, and the
> lighting] unchanged.

### Style transfer — same content, new style
> Transform the provided photograph of [a city street at night] into the style
> of [Van Gogh's "Starry Night"]. Preserve the original composition of buildings
> and cars, but render everything with [swirling impasto brushstrokes, deep blues
> and bright yellows].

### Combine multiple images (compose a new scene)
> Create [a professional e-commerce fashion photo]. Take [the dress from the
> first image] and have [the woman from the second image] wear it. Full-body
> shot, lighting and shadows adjusted to match [an outdoor environment].

### High-fidelity detail preservation
Describe the thing to preserve in words AND supply it as a reference.
> Take [the woman in the first image]. Add [the logo from the second image] onto
> [her t-shirt]. Ensure [her face and features] remain completely unchanged; the
> logo should follow the fabric folds as if printed.

### Sketch → finished image
> Turn this rough pencil sketch of [a futuristic car] into [a polished photo of
> the finished concept car in a showroom]. Keep [the sleek lines and low profile]
> from the sketch but add [metallic blue paint and neon rim lighting].

---

## Character consistency (the reference-image workflow)

The pattern for "same subject, many poses/styles":

1. **Hero shot.** Establish one strong image of the subject (generate or supply).
2. **Reference every time.** Pass the hero (and later, more angles) as `-r` refs.
3. **Lock identity in words.** Add "keep the face, hair, and features from image 1
   exactly; change only [pose/outfit/setting]."
4. **New angle per call** for a turnaround:
   > A studio portrait of [the person in the reference images], against a seamless
   > white background, [in profile, looking right]. Keep their face and features
   > identical to the references.
5. Accumulate front / 3-4 / profile references; reuse all of them on later prompts.

Per-call limits: `flash` holds up to 4 characters + 10 objects; `pro` up to 5
characters + 6 objects; 14 images total either way.

---

## Iteration phrases that work

- "Keep everything the same, but [make the lighting warmer]."
- "That's close — now [change her expression to a soft smile]."
- "Same composition, [wider shot]."
- "Redo in [the style of the third reference image]."
