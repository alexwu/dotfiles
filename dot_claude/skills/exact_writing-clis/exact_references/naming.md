# Naming

Precedence: smallstep ("The Poetics of CLI Command Names") carries the heuristics,
clig.dev the basics, POSIX G1/G2 cited then amended. House amendments marked
`DEVIATION:`.

Names are the highest-stakes decision a CLI makes: everything else can be
versioned, deprecated, or aliased — the name gets baked into scripts, muscle
memory, and docs, and renaming later breaks all three. Short names are a scarce,
high-value resource; spend them deliberately.

## Binary names

### The base rules

- **Lowercase only** (clig; POSIX G2: lowercase letters + digits from the portable
  charset).
- POSIX G1: 2–9 characters. `DEVIATION:` kebab-case multi-word names are allowed
  for niche tools — `electron-apps`, `heic-ai-rename`, `gif-mosaic`,
  `persona-anchor` are house precedent. G1/G2 target universally-invoked
  utilities; a Hazel-invoked tool typed once a month earns clarity over brevity.
- **No shift-key characters, ever** — no capitals (`VirtualBox`), no underscores
  (`easy_install`), no emoji. Friction paid on every invocation forever.
- **No version numbers in the name** (`python3.7m`) — a permanent scar of a
  packaging failure.
- **Ban generic filler words**: never `tool`, `kit`, `util`, `easy` — they
  describe packaging, not function.
- **The `g` prefix is claimed** (GNU, since 1983). More generally: check whether
  a prefix is already someone's namespace before squatting on it.
- **No prefix/namespace on house binaries** — `memo`, not `lulu-memo`. The one
  real namespace is `LULU_*` env vars for actual lulu tooling; don't extrapolate
  it to binary names.

### Length scales inversely with frequency

"The more niche your command, the longer its name should be. Very short names
should be reserved for utilities people use all the time" (smallstep). `cd`, `ls`,
`rg` earn 2 chars by being typed hundreds of times a day. House calibration:

| Frequency | Length | House examples |
|---|---|---|
| Many times daily | 2–4 chars | `lu`, `memo`, `zn` |
| Weekly-ish | one word | `chain`, `tokens`, `speak`, `wezrun` |
| Rare / machine-invoked | kebab phrase | `heic-ai-rename`, `git-readonly-guard` |

### The ergonomic tests

- **One-hand test**: can you type it with one hand, like `cat`, while the other
  hand is on the mouse? (Docker Compose renamed `plum` → `fig` for exactly this.)
- **Poetry test**: would it read as a word in a poem? `curl`, `fold`, `awk` yes;
  `AssetCacheTetheratorUtil` no. Tests phonetic shape and brevity together.
- **Typing feel**: `sha256sum` is "gargling sand"; `capinfos` is "a soft breeze
  across the keys." Finger travel and rhythm are UX.
- **Global pronounceability**: names get spoken (teaching, screencasts) as often
  as typed. Kodak engineered for cross-language consistency.

### Longevity rules

- **Never name after a protocol, standard, or format**: `openssl` can never become
  `opentls`; `ffmpeg` does far more than fast-forward MPEG. You inherit the
  standard's obsolescence risk plus rename lock-in.
- **Never name after the implementation tech**: `cfdisk` (Curses fdisk) — "imagine
  if Slack called itself `webirc`." Implementation is a detail, and the wrong
  mental model.
- **Never claim a generic word**: ImageMagick's `convert` collided with Windows'
  `convert`; v7 retreated to `magick` with a `convert` subcommand. A bare generic
  verb over-promises universal scope and isn't yours to claim.
- **Prefix families narrow a generic claim**: `mkfs` is fine because `mkdir`,
  `mknod`, `mktemp` establish the `mk*` family convention. A family is a
  legitimate way to use a literal name without the land-grab.
- **Thoughtful meaninglessness is often the best option** when the solution domain
  will evolve. smallstep's `step`/`step-ca`: no literal PKI connection, easy to
  type, won't go stale as scope shifts. Contrast `emacs` ("I still don't know what
  an emac is"). A name coupled to today's functionality is a liability;
  ergonomically-good + semantically-neutral has no expiration date.
- **Keep name and scope independent**: "don't depend on your command's name to
  determine its scope." The name is a handle, not a spec.
- **Careful with deep-lore naming** — a mythology reference that only resonates
  for the namer fails the user.
- **Don't proliferate top-level binaries**: "install one or two commands, and use
  subcommands." Each new binary taxes PATH, tab-completion, and muscle memory.
  Git's model — own `git`, extend via `git-<command>`-in-PATH — adds surface
  without pollution (`git-readonly-guard` follows it).

## Subcommand names

- **Single lowercase words** (Heroku; house `dispatchMulti` style: `memo gc`,
  `speak voices`). Kebab only when unavoidable (`persona-anchor session-start` —
  hook event names forced it).
- **`noun verb` grammar**, verbs consistent across nouns: if sessions have
  `list/show/rm`, models have `list/show/rm` — not `ls/info/delete`.
- **The bare noun lists its resources** — `lu sessions` IS the list command; never
  add a `sessions list` duplicate (Heroku: "never create a `*:list` command").
- **No ambiguous near-synonym pairs**: `update` vs `upgrade` is the canonical
  trap (clig). If both exist, one is wrong.
- **No homonyms across the flag/subcommand boundary**: `lu schema` (subcommand)
  coexisting with `--schema` (flag) forced the docs into a "not to be confused
  with" warning. If you're writing that warning, rename one of them.
- **The accretion rule** (the `lu` lesson): a single-purpose tool that grows its
  first second noun must promote the original bare behavior to an explicit verb
  in the same change (`lu <prompt>` → `lu run <prompt>`), moving its flags with
  it. A bare-root default can remain as shorthand (memo's default-to-run:
  `memo cargo test` ≡ `memo run -- cargo test`) but the explicit verb is the
  documented, canonical form.

## Flag names

- Long form: kebab-case (`--dry-run`, `--only-failures`, `--cell-width`).
- Short form only for the frequent (house: `-n`, `-m`, `-p`, `-i`, `-o`, `-j`);
  the short-flag namespace is scarce — don't burn letters on rarities.
- Standard names first — check the table in `arguments-and-flags.md` before
  inventing (`-o/--output` exists; `--dest` is a synonym nobody can guess).
- `-v` = verbose, `-V --version` = version (house ruling, matches clap defaults).

## The worksheet

For any name that will outlive the session — binary, subcommand, or flag:

1. **Generate 5+ candidates.** Include at least one literal-descriptive, one
   metaphor, and one thoughtfully-meaningless option. Don't stop at the first
   plausible name.
2. **Run the quick-gate on each** (SKILL.md §Naming quick-gate): frequency-length
   fit, one-hand test, poetry test, collision check (`command -v <name>`,
   `which -a <name>`, quick brew/crates/npm search), longevity check.
3. **Say the survivors aloud.** If you'd hesitate to say it in a screencast, cut
   it.
4. **Check tab-completion uniqueness**: does it disambiguate from everything on
   your PATH within 2–3 chars? (`compgen -c | rg '^<prefix>'` or just hit tab.)
5. **For anything installed: sleep on it.** A name that still feels right the
   next day is a different signal than one that felt clever at midnight.

### Worked example — naming a clipboard-history tool

Candidates: `cliphist` (literal), `clipboard-history` (literal-long), `paste`
(generic verb), `snip` (metaphor), `carousel` (meaningless-ish), `clip` (short
literal).

- `paste` — eliminated instantly: POSIX `paste(1)` exists (collision + generic
  claim, the `convert` mistake).
- `clipboard-history` — fails frequency-length: this is a many-times-daily tool;
  17 chars is a niche-tool budget.
- `cliphist` — passes collision locally, but fails the poetry test (consonant
  pile-up, "gargling sand" territory) and an ecosystem search finds an existing
  Wayland `cliphist`. Out.
- `clip` — one hand, 4 chars, poetic. But it's a generic-word claim (Windows has
  `clip.exe`; several package managers carry a `clip`) and names the *domain*,
  locking scope to clipboards forever.
- `snip` — one hand, poetic, pronounceable. Metaphor slightly wrong (snipping is
  cutting, not recalling) and collides with Windows Snipping Tool mindshare.
- `carousel` — the meaning fits beautifully (a rotating tray of things you take
  from) but 8 chars + two-hand typing for a daily tool fails frequency-length.

None survive cleanly — which is the realistic outcome of round one. Round two
mines the metaphor space ("recall", "echo", "again") and thoughtful
meaninglessness. `yoink` — real word, one-ish hand, poetic, pronounceable,
zero PATH collisions, scope-neutral (yoinking generalizes past clipboards) —
passes every gate. That two-round shape is normal; budget for it.

## Checklist (for audits)

- [ ] Lowercase; kebab only if multiword and niche (`DEVIATION` from POSIX G1/G2)
- [ ] Length matches invocation frequency
- [ ] One-hand + poetry + pronounceability pass
- [ ] No collision on PATH / brew / crates / npm
- [ ] Not a protocol/standard/format/tech name; no version number; no generic claim
- [ ] Subcommands: single words, noun-verb, consistent verbs, bare-noun-lists
- [ ] No flag/subcommand homonyms; no `update`/`upgrade`-style near-synonyms
- [ ] Accretion rule honored: bare-root behavior only as a documented shorthand
      for a canonical explicit verb (`memo <cmd>` ≡ `memo run -- <cmd>`); reject
      it when no such verb exists
