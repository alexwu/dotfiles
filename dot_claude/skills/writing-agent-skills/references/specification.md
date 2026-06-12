# SKILL.md Specification

The complete format reference. Source of truth for frontmatter fields, directory roles, and validation.

## Directory structure

A skill is a directory containing, at minimum, a `SKILL.md`:

```
skill-name/
├── SKILL.md          # required: metadata + instructions
├── scripts/          # optional: executable code
├── references/       # optional: load-on-demand documentation
├── assets/           # optional: templates, schemas, data files
└── ...               # any additional files
```

## Frontmatter

YAML frontmatter, then Markdown body.

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | yes | ≤64 chars; lowercase letters, digits, hyphens; no leading/trailing/consecutive hyphen; must match the parent directory name |
| `description` | yes | 1–1024 chars, non-empty; what it does **and** when to use it |
| `license` | no | license name or bundled-file reference; keep short |
| `compatibility` | no | 1–500 chars; environment requirements (product, packages, network). Most skills omit it |
| `metadata` | no | arbitrary `string → string` map; use unique-ish keys to avoid collisions |
| `allowed-tools` | no | space-separated pre-approved tools. **Experimental** — support varies |

Minimal:

```yaml
---
name: skill-name
description: A description of what this skill does and when to use it.
---
```

With optional fields:

```yaml
---
name: pdf-processing
description: Extract PDF text, fill forms, merge files. Use when handling PDFs.
license: Apache-2.0
metadata:
  author: example-org
  version: "1.0"
---
```

### `name`

- 1–64 chars, only `a-z`, `0-9`, and `-`.
- No leading/trailing hyphen, no `--`.
- **Must match the parent directory name.**

Valid: `pdf-processing`, `data-analysis`, `code-review`
Invalid: `PDF-Processing` (uppercase), `-pdf` (leading hyphen), `pdf--processing` (double hyphen)

### `description`

- 1–1024 chars.
- Describe **what** the skill does and **when** to use it.
- Include specific keywords that help the agent match relevant tasks.

Good: `Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs. Use when working with PDF documents or when the user mentions PDFs, forms, or document extraction.`
Poor: `Helps with PDFs.`

This is the single most important field — it carries the entire triggering burden. See `optimizing-descriptions.md`.

### `license`

License applied to the skill. Keep short — a license name or a bundled-file reference, e.g. `Proprietary. LICENSE.txt has complete terms`.

### `compatibility`

1–500 chars, only when the skill has real environment requirements:

```
compatibility: Requires git, just, and ripgrep on PATH
compatibility: Designed for Claude Code (or similar products)
```

### `metadata`

String→string map for client-specific properties the spec doesn't define:

```yaml
metadata:
  author: example-org
  version: "1.0"
```

### `allowed-tools`

Space-separated pre-approved tools — **experimental**, support varies between agents:

```
allowed-tools: Bash(git:*) Bash(jq:*) Read
```

## Body content

No format restrictions — write whatever helps the agent. Recommended sections: step-by-step instructions, input/output examples, common edge cases. The agent loads the **entire** body on activation, so split long content into referenced files (see progressive disclosure).

## Optional directories

### `scripts/`

Bundled executable code. Scripts should be self-contained or clearly document dependencies, include helpful errors, and handle edge cases. For the **language policy in this environment** (which languages are allowed and which are deliberately excluded) and for designing scripts agents can drive, see `using-scripts.md`.

### `references/`

Load-on-demand documentation (`REFERENCE.md`, domain files like `finance.md`). Keep each file focused — agents load them on demand, so smaller files mean less context spent. Always tell the agent the **trigger condition** for loading a reference.

### `assets/`

Static resources: templates, images/diagrams, data files (lookup tables, schemas).

## Progressive disclosure

Agents pull in detail only as the task calls for it. Three tiers:

1. **Metadata** (~100 tokens) — `name` + `description`, loaded at startup for every skill.
2. **Instructions** (recommended **< 5000 tokens**) — the full `SKILL.md` body, loaded on activation.
3. **Resources** — files in `scripts/`, `references/`, `assets/`, loaded only when needed.

Keep `SKILL.md` **under 500 lines**. Move detailed reference material into separate files, and name the condition under which each should be read.

## File references

Reference other files with **relative paths from the skill root**:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the validator:
scripts/validate
```

Keep references **one level deep** from `SKILL.md`. Avoid deeply nested reference chains.

## Validation

The upstream [`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref) library validates frontmatter and naming:

```
skills-ref validate ./my-skill
```

Checks that the frontmatter is valid and naming conventions hold. A quick manual pass covers the essentials: `name` matches the directory, `description` is non-empty and ≤1024 chars, required fields present, body under the line/token budget.
