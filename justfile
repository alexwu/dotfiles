# Dev tasks for the chezmoi dotfiles source tree.
#
# NOTE: this is a plain `justfile` (no dot_ prefix), so chezmoi treats it as a
# target and would deploy it to ~/justfile. It's kept source-only by a matching
# `justfile` line in .chezmoiignore — remove that line and ~/justfile reappears.
#
# Run with plain `just` from the repo (`J` = `just -g` targets the global one).

default:
    @just --list

# Format all main languages in place (shell, nim, lua, markdown).
fmt: fmt-sh fmt-nim fmt-lua fmt-md

# Shell & zsh — shfmt (all options from .editorconfig).
fmt-sh:
    shfmt -w .

# Nim — nph (sources live under scripts/).
fmt-nim:
    fd -e nim . -X nph

# Lua — stylua (-s finds the right stylua.toml per subtree).
fmt-lua:
    stylua -s .

# Markdown — rumdl (config from ~/.config/rumdl/rumdl.toml).
fmt-md:
    rumdl fmt .

# TOML — taplo (standalone; not part of `fmt`).
fmt-toml:
    taplo fmt .

# Fish — fish_indent (standalone; not part of `fmt`).
fmt-fish:
    fd -e fish . -X fish_indent -w

# Re-scrape the writing-claude-prompts sources into .firecrawl/, diff each page
# against its previous scrape, and list prompt-engineering pages the manifest
# lacks. Fetches and diffs only; updating the skill is the agent's job.
[doc("Re-scrape the Claude prompting docs, diff them, and list unlisted guides")]
refresh-prompting-docs:
    #!/usr/bin/env bash
    set -euo pipefail
    manifest=dot_claude/skills/writing-claude-prompts/references/sources.md
    index=https://platform.claude.com/docs/en/build-with-claude/prompt-engineering
    out=.firecrawl
    prev="$out/prev"
    mkdir -p "$prev"

    urls=$(rg -o '^\| *[a-z0-9-]+ *\| *<(https://[^>]+)>' -r '$1' "$manifest" || true)
    if [ -z "$urls" ]; then
      echo "refresh-prompting-docs: no source rows found in $manifest" >&2
      exit 1
    fi

    changed=()
    for url in $urls; do
      slug=${url##*/}
      file="$out/$slug.md"
      [ -f "$file" ] && cp "$file" "$prev/$slug.md"

      # Firecrawl sometimes backslash-escapes a page: lines ending in `[\`,
      # `,\`, `}\`, lines that are a bare `\`, or `\-\-\-`. The docs serve clean
      # markdown at <url>.md, so fall back to that. The two sources format the
      # same page differently, so once a page has come back raw (it starts
      # with `---` frontmatter; firecrawl output never does), keep fetching it
      # raw so the diff shows content changes rather than a source flip.
      if [ -f "$prev/$slug.md" ] && [ "$(head -n 1 "$prev/$slug.md")" = "---" ]; then
        curl -sSfL "$url.md" -o "$file"
      elif ! firecrawl scrape "$url" --only-main-content -o "$file" >/dev/null; then
        echo "$slug: firecrawl failed; fetching $url.md" >&2
        curl -sSfL "$url.md" -o "$file"
      elif rg -q '^\\$|[\[{},\]]\\$|\\-\\-\\-' "$file"; then
        echo "$slug: firecrawl output is escaped; fetching $url.md" >&2
        curl -sSfL "$url.md" -o "$file"
      fi

      echo "=== $slug ($url)"
      if [ ! -f "$prev/$slug.md" ]; then
        echo "(no previous scrape; new page)"
        changed+=("$slug")
      elif diff -u "$prev/$slug.md" "$file"; then
        echo "(unchanged)"
      else
        changed+=("$slug")
      fi
    done

    echo "=== pages under the prompt-engineering index missing from the manifest"
    firecrawl map "$index" --limit 500 -o "$out/prompt-engineering-map.txt" >/dev/null
    missing=$(comm -23 \
      <(rg -o 'https://platform\.claude\.com/docs/en/build-with-claude/prompt-engineering/[a-z0-9-]+' "$out/prompt-engineering-map.txt" | sort -u) \
      <(printf '%s\n' $urls | sort -u))
    echo "${missing:-(none)}"

    echo "=== summary"
    echo "changed: ${changed[*]:-(none)}"

# Check formatting across the main languages without writing (non-zero on drift).
fmt-check:
    shfmt -d .
    fd -e nim . -X nph --check
    stylua -s --check .
    rumdl check .
