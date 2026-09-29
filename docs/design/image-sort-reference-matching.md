# Design: reference-image matching for image-sort `lulu` detection

Status: **proposal** (not built). Decide whether the "reject clearly-not-her" win
justifies the build before implementing.

## Problem

`image-sort` currently decides `lulu | screenshot | other` purely from the vision
LLM's freeform judgment ("is the subject the reference person?"). That judgment
**over-fires**: it tags a whole *genre* — "stylized/fantasy woman, often with a
sword or armor, attractive" — as `lulu`, rather than the *specific* subject.

Observed false positives (all manually corrected to `Other`):

| File (model-generated name) | What it actually is | Why it's wrong |
|---|---|---|
| `blonde-woman-samurai-…holding-sword` | clearly **dark-haired** woman, kimono | model wrote "blonde" on a brunette, called it lulu |
| `battle-worn-female-warrior-kneeling-with-sword` | **brunette**, photoreal | wrong subject, wrong hair |
| `blonde-woman-crouching-posing-hand-gesture` | **B&W ink** Android 18 | monochrome → "blonde" is a pure guess |

The model also conflates blonde vs brunette outright (the samurai), partly because
small MoE vision models blur fine attributes, partly because line-art/monochrome
carries no colour signal.

## Key finding from the canonical reference set

Inspecting six user-blessed "canonical" references (spanning `anime`, `realistic`,
`cartoon`) shows:

- **Invariant identity signal:** blonde, green eyes, petite/slender, fair skin,
  soft youthful face, frequent glasses, white-top wardrobe.
- **Heavy variation:** render style (cel-anime → loose sketch → photoreal → painted
  cartoon), hair length/style (long wavy / straight / ponytail), glasses on/off,
  scene. The three *photoreal* refs aren't even the **same face** — they're separate
  generations of the same *type*.

**Conclusion: there is no canonical _face_, only a canonical _type_.** This caps
what any matcher can do (see Limitations) and dictates the architecture.

## Goal / non-goals

- **Goal:** a *gate* that rejects clearly-not-her inputs the LLM wrongly tags
  `lulu` (the three above would all be caught). Reduce false positives.
- **Non-goal:** a precise "this is exactly Luna" oracle. The archetype is common
  (blonde + green eyes + glasses + petite); distinguishing the subject from a
  *different* girl of the same type is likely not decidable from these references.
  Treat this as **"reject obvious misses,"** not identity verification.

## Approach: per-style reference buckets + a similarity gate

1. Keep the LLM call for `category` (initial), `style`, and `name` — we need style
   and name regardless.
2. Maintain a **curated** reference set bucketed by style:
   `~/.config/image-sort/references/{anime,realistic,cartoon}/*.png` (kept OUT of
   the public chezmoi repo, like the schema/prompt — it's appearance content).
3. When the LLM says `lulu`: embed the working PNG, compare against the
   **style-matched** bucket (the model already told us the style), take the
   max (or top-k mean) similarity. If it clears the bucket's threshold → keep
   `lulu`; else **demote** to `other` (or route to a `Lulu/_review/` holding pen
   for a human glance — softer failure than silent demotion).

Embeddings cluster by *style* as much as by identity, so matching anime→anime and
realistic→realistic (rather than one global threshold) is what makes it work.

## Embedding model options

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Apple Vision `VNGenerateImageFeaturePrintRequest`** → `VNFeaturePrintObservation.computeDistance` | on-device, **zero deps / no model download**, fast, works on any image | general perceptual descriptor (also style-biased → hence buckets); macOS-only | **recommended v1** |
| **fastembed-rs** (ONNX CLIP / SigLIP) | Rust, fast, stronger semantic embeddings, cross-platform | model download; ONNX runtime dep | alt if Vision under-discriminates |
| **DINOv2** (ONNX) | best for *instance/subject* similarity, least style-biased | heaviest; Python/ONNX | escalation for hard cases |
| **insightface ArcFace** (face-ID) | strong face separation | photoreal only (useless on anime/cartoon); realistic refs aren't one face, so limited gain | optional realistic-bucket booster |

**Recommendation:** start with **Apple Vision feature prints**. It fits the macOS +
no-Python ethos, needs no model artifact, and is the cheapest path to a working
gate. The embedding step is the one place a tiny **Swift CLI** beats Nim/Rust
(it's a macOS-framework call): e.g. `feature-print <img>` → emits the feature-print
vector (or `feature-dist <a> <b>` → distance). Escalate to SigLIP/DINOv2 only if v1
can't separate the positives from the known negatives.

## Threshold tuning methodology

We already have a labelled validation set on disk:

- **Positives:** the curated reference set (+ other confirmed `Lulu/` files).
- **Negatives:** the three corrected files above, plus any future move-backs.

Pick the per-bucket threshold that accepts the positives while rejecting the
negatives, with margin. Re-tune when the reference set changes. Log every gate
decision (kept / demoted + score) so misses are auditable.

## Architecture / data flow

```
input → LLM (category, style, name)
            │ category == lulu?
            ├─ no  → route as today
            └─ yes → feature-print(workPng)
                     → compare vs cached vectors of references/<style>/
                     → maxSim ≥ threshold[style] ? keep lulu : demote→other (or _review)
```

- **Vector cache:** precompute reference feature prints once into
  `~/.config/image-sort/references/<style>/.vectors.json`; rebuild when the bucket's
  file hashes change (an `image-sort refs rebuild` subcommand).
- **Curation workflow:** `image-sort refs add <style> <img>` / `refs list` so the
  set stays hand-picked — a "failed attempt" left in a bucket poisons it.

## Integration points in `image_sort.nim`

- New step after decode, gated on `category == "lulu"`.
- New helper to call `feature-print` and read cached bucket vectors (reuse the
  existing `run`/`tryRun`; vectors via the repo's `json_serialization` convention).
- Routing change: a demotion path (lulu → other, or → `Lulu/_review/`).
- Config: reference root + per-style thresholds (env or a small config file).

## Limitations (honest)

- **Reliably catches** gross misses (wrong hair, wrong style, monochrome, wrong
  subject) — the three observed false positives.
- **Cannot reliably separate** the subject from a *different* same-type girl —
  there's no unique face in the references to lock onto. This is a ceiling of the
  data, not the method.
- Style misclassification by the LLM picks the wrong bucket → wrong comparison.
  Mitigation: fall back to comparing against *all* buckets if style confidence is
  low (no style field today; would need to add one).
- Reference quality dominates. Garbage refs → garbage gate. Curation is mandatory.

## Open decisions for Alex

1. **Demote silently to `other`, or route to a `Lulu/_review/` holding pen?**
   (Review pen = safer, but you have to empty it.)
2. **Swift CLI for Vision feature prints OK?** (It's the natural fit; the only
   non-Nim/Rust piece.)
3. **Reference root:** `~/.config/image-sort/references/` vs an iCloud path so it
   syncs across machines.
4. Scope v1 to the **anime + realistic** buckets only (most volume), defer cartoon?

## Rough build sequence

1. `feature-print` Swift CLI (emit vector + a `dist` mode); verify it separates the
   6 positives from the 3 negatives at *some* threshold (kill-criterion: if it
   can't, escalate embedding model before building more).
2. Reference store + `refs rebuild`/`add`/`list` + vector cache.
3. Gate in `image_sort.nim` (+ demotion/review routing, decision logging).
4. Threshold tuning on the positive/negative set; document chosen thresholds.
5. Update `.claude/rules/hazel.md`.
