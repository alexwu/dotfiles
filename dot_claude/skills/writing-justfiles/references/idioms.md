# Justfile Idioms — Reference

Opinionated patterns drawn from real-world justfiles — primarily Alex's global justfile at `~/.config/just/justfile`. Not exhaustive: just the recurring shapes that separate a justfile written *with* just from one written *against* it. Pair with the deep references when you need full syntax — every pattern below links to the section that owns the underlying mechanics.

## Contents

- [1. Default recipe = list everything](#1-default-recipe--list-everything)
- [2. `[group(...)]` + `[doc(...)]` on every recipe](#2-group--doc-on-every-recipe)
- [3. Shebang recipes for multi-line bash with strict mode](#3-shebang-recipes-for-multi-line-bash-with-strict-mode)
- [4. Always `quote()` user-supplied params before bash interpolation](#4-always-quote-user-supplied-params-before-bash-interpolation)
- [5. `[arg]` to flagify recipe params](#5-arg-to-flagify-recipe-params)
- [6. `[no-cd]` on any recipe taking a path argument](#6-no-cd-on-any-recipe-taking-a-path-argument)
- [7. `[confirm]` on destructive ops](#7-confirm-on-destructive-ops)
- [8. Brace escaping for embedded `{{` literals](#8-brace-escaping-for-embedded--literals)
- [9. `[parallel]` for cheap fan-out](#9-parallel-for-cheap-fan-out)
- [10. OS gates for cross-platform recipes](#10-os-gates-for-cross-platform-recipes)
- [Anti-patterns](#anti-patterns)

---

### 1. Default recipe = list everything

The first recipe runs when `just` is invoked with no args. Make it `--list` (`-l`) so the on-ramp is "show me what's here," not "fail because no recipe is named `default`." The leading `@` suppresses echo so the listing isn't preceded by the command itself.

```just
default:
    @just -g -l
```

`-g` (global) is specific to the `~/.config/just/justfile` use case — drop it for project-local justfiles. Deep dive: [`recipes.md`](recipes.md) covers the `[default]` attribute as an alternative to "first recipe wins."

---

### 2. `[group(...)]` + `[doc(...)]` on every recipe

Keeps `just -l` self-documenting. Without these two, every recipe needs a history dig to remember what it did. With them, the listing is the docs.

```just
[group("docker")]
[no-cd]
docker-build COMPOSE:
    docker compose -f {{ COMPOSE }} up --build
```

```just
[group("llm")]
[doc("List models exposed by llama-swap")]
llm-models:
    xh -b GET {{ LLAMA_SWAP }}/v1/models
```

`just --groups` lists group names; `just --list` prints recipes grouped with the doc as a trailing comment. Both attributes also apply to `mod` statements. Deep dive: [`attributes.md#groupname`](attributes.md#groupname) and [`attributes.md#doc--docdoc`](attributes.md#doc--docdoc).

---

### 3. Shebang recipes for multi-line bash with strict mode

Plain (line-by-line) recipes spawn a fresh shell per line — `cd`, shell variables, and control flow do not carry across. For anything multi-step, write a shebang recipe and turn on strict mode. `set -euo pipefail` is the baseline; add `-x` (`set -euxo pipefail`) when you want every line echoed for debugging.

```just
[group("tree-sitter")]
[doc("Refresh tree-sitter grammars: hx fetch + build, then rebuild tree-sitter-<lang> symlinks")]
ts-grammars-update:
    #!/usr/bin/env bash
    set -euo pipefail
    hx --grammar fetch
    hx --grammar build
    SOURCES_DIR="$HOME/.config/helix/runtime/grammars/sources"
    PARSERS_DIR="$HOME/.local/share/tree-sitter/parsers"
    mkdir -p "$PARSERS_DIR"
    find "$PARSERS_DIR" -maxdepth 1 -type l -name 'tree-sitter-*' -delete
    count=0
    for src in "$SOURCES_DIR"/*/; do
        [[ -d "$src" ]] || continue
        src="${src%/}"
        ln -sf "$src" "$PARSERS_DIR/tree-sitter-$(basename "$src")"
        count=$((count + 1))
    done
    echo "linked $count grammars into $PARSERS_DIR"
```

The whole body is one script — variables persist, `for` loops work, `set -e` actually means something. Deep dive: [`scripts.md`](scripts.md) covers shebang recipes, the `[script]` attribute, and `set script-interpreter`.

---

### 4. Always `quote()` user-supplied params before bash interpolation

`{{ name }}` interpolation pastes the parameter value *raw* into the recipe line — spaces, quotes, `$`, and backticks all reach the shell unescaped. `{{ quote(name) }}` wraps the value as a single-quoted shell string (escaping any embedded `'`), making it safe to pass to bash.

```just
[group("llm")]
[doc("Chat completion: just llm-chat [-m MODEL] [--stream] PROMPT...")]
[arg("model", long, short="m")]
[arg("stream", long, value="true")]
llm-chat model=LLM_DEFAULT_MODEL stream="false" +prompt="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z {{ quote(prompt) }} ]]; then
        echo "error: prompt required" >&2
        exit 1
    fi
    body=$(jaq -n --arg m {{ quote(model) }} --arg p {{ quote(prompt) }} --argjson s {{ stream }} \
        '{model: $m, messages: [{role: "user", content: $p}], stream: $s}')
```

Unsafe vs safe contrast:

```just
# Unsafe — newlines, $, backticks, spaces in PROMPT break the shell or inject.
echo {{ prompt }} | jaq -n --arg p "$1" '{...}'

# Safe.
echo {{ quote(prompt) }} | jaq -n --arg p "$1" '{...}'
```

Three escape hatches when `quote()` doesn't fit: use `set positional-arguments` and reference `"$1"` instead; export with `$NAME` and reference `"$NAME"`; or pre-quote the entire interpolation site (`'http://x/?q={{ Q }}'`). Deep dive: [`built-in-functions.md`](built-in-functions.md) for `quote()` and the rest of the string family; [`expressions.md`](expressions.md) for argument-splitting hazards.

---

### 5. `[arg]` to flagify recipe params

Once a recipe has more than one optional param, plain positional args get awkward (`just deploy "" "" verbose`). `[arg(NAME, ...)]` converts a positional parameter into a long flag, short flag, or boolean flag — and `just` then generates `--help` / `--usage` from the schema for free.

```just
[group("llm")]
[doc("Chat completion: just llm-chat [-m MODEL] [--stream] PROMPT...")]
[arg("model", long, short="m")]
[arg("stream", long, value="true")]
llm-chat model=LLM_DEFAULT_MODEL stream="false" +prompt="":
    ...
```

Now `just llm-chat -m claude-opus-4-7 --stream "say hi"` works. Keys:
- `long` (no value) — defaults the long-flag name to `--<param>`.
- `short="m"` — adds a short alias.
- `value="true"` — makes it a boolean flag that injects the literal `"true"` when present.
- `pattern='\d+\.\d+\.\d+'` — regex validation; `^...$` is added implicitly.

Variadic `*` / `+` parameters can't be options. Deep dive: [`attributes.md#arg--argument-constraints--flagify-parameters`](attributes.md#arg--argument-constraints--flagify-parameters).

---

### 6. `[no-cd]` on any recipe taking a path argument

By default, `just` `cd`s into the directory containing the justfile before running each recipe. That's wrong for any recipe whose purpose is to operate on a file the user named — the user is naming it relative to *their* shell, not the justfile's.

```just
[group("mac")]
[no-cd]
remove-quarantine FILE:
    xattr -d com.apple.quarantine {{ FILE }}
```

Without `[no-cd]`, `just remove-quarantine ./downloads/foo.dmg` would try to resolve `./downloads/foo.dmg` against `~/.config/just/`, which is almost never what the user intends. Deep dive: [`attributes.md#no-cd`](attributes.md#no-cd).

---

### 7. `[confirm]` on destructive ops

Cheap insurance. Anything that kicks a launchd agent, deletes files, force-pushes, drops a database, or restarts a daemon should ask first. The expression form (1.49.0+) lets the prompt mention what's actually being affected.

```just
[group("llm")]
[doc("Restart the llama-swap launchd agent")]
[confirm("Restart llama-swap? This will interrupt any running requests.")]
llm-restart:
    launchctl kickstart -k gui/$(id -u)/com.github.mostlygeek.llama-swap
```

`just --yes` auto-confirms across the run. A recipe whose dependency requires confirmation is skipped if the dep is declined — so `[confirm]` propagates correctly through dep chains. Deep dive: [`attributes.md#confirm--confirmprompt`](attributes.md#confirm--confirmprompt) and [`recipes.md#7-confirmation-behaviour`](recipes.md#7-confirmation-behaviour).

---

### 8. Brace escaping for embedded `{{` literals

When a recipe must emit `{{ ... }}` to a downstream tool that itself consumes that syntax (Lua tables, Mustache, Handlebars, Jinja), use `{{{{ ... }}}}` to produce the literal `{{ ... }}`. The matching `}}}}` produces `}}`.

```just
[group("lumis")]
[doc("Regenerate snazzy theme JSON for lumis. Re-adds to chezmoi source on success.")]
lumis-regen-snazzy:
    #!/usr/bin/env bash
    set -euo pipefail
    out="$HOME/.local/share/lumis/themes/snazzy.json"
    lumis themes generate \
        -u https://github.com/alexwu/nvim-snazzy \
        -c snazzy \
        -s 'vim.pack.add({{{{ src = "https://github.com/rktjmp/lush.nvim" }}}}, { load = true, confirm = false }); vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/site/pack/core/opt/lush.nvim")' \
        -o "$out"
    chezmoi re-add "$out"
```

`{{{{ src = "..." }}}}` reaches the shell as the literal string `{{ src = "..." }}` — the Lua-table literal that `vim.pack.add` expects. Deep dive: [`expressions.md#3-string-interpolation-and-brace-escaping`](expressions.md#3-string-interpolation-and-brace-escaping).

---

### 9. `[parallel]` for cheap fan-out

When a recipe's dependencies are independent (lint + format-check + audit; build for three targets; sync three repos), `[parallel]` makes them concurrent at zero cost. Without the attribute, deps run sequentially in declaration order.

```just
[parallel]
check: lint format-check audit

lint:
    cargo clippy -- -D warnings

format-check:
    cargo fmt --check

audit:
    cargo audit
```

`lint`, `format-check`, and `audit` run concurrently before `check` itself runs. Use only when deps don't share state — interleaved stdout is fine, but interleaved writes to the same file are not. Deep dive: [`attributes.md#parallel`](attributes.md#parallel) and [`recipes.md`](recipes.md).

---

### 10. OS gates for cross-platform recipes

Same recipe name with `[macos]`/`[linux]`/`[windows]` attributes lets one invocation work everywhere. just picks the variant matching the current OS; if no variant matches, the recipe is unavailable.

```just
[macos]
open URL:
    open {{ URL }}

[linux]
open URL:
    xdg-open {{ URL }}

[windows]
open URL:
    start {{ URL }}
```

Other gates: `[unix]` (any unix incl. macOS), `[android]`, `[freebsd]`, `[netbsd]`, `[openbsd]`, `[dragonfly]`. Multiple gates on one recipe = enabled if *any* match. Deep dive: [`attributes.md#os-configuration-gates`](attributes.md#os-configuration-gates).

---

## Anti-patterns

| Don't | Do | Why |
|-------|-----|-----|
| Multi-line `if`/`for`/`cd` in a line-by-line recipe body | Use a shebang recipe (`#!/usr/bin/env bash` + `set -euo pipefail`) — see [`scripts.md`](scripts.md) | Each plain recipe line is a fresh shell; `cd`, vars, and control flow don't carry across |
| `cd subdir` on its own line, expecting later lines to inherit | `cd subdir && next-command` on one line, OR shebang recipe | Same fresh-shell-per-line reason |
| `lynx http://x/?q={{ QUERY }}` (raw interpolation) | `lynx 'http://x/?q={{ QUERY }}'`, OR `{{ quote(QUERY) }}`, OR `[positional-arguments]` + `"$1"`, OR `$QUERY` exported — see [`built-in-functions.md`](built-in-functions.md) and [`expressions.md`](expressions.md) | Whitespace, quotes, `$`, or backticks in `QUERY` trigger shell argument splitting or injection |
| Reaching for mise's `usage = '''…'''` block syntax | Use `[arg(...)]` attributes — that's just's native flag system. See [`attributes.md#arg--argument-constraints--flagify-parameters`](attributes.md#arg--argument-constraints--flagify-parameters) | mise's `usage` field doesn't exist in just — different tool, different DSL |
| Hand-rolling `--help`/`--version` parsing in bash | `[arg("flag", long, value="true")]` + a default — see [`attributes.md#arg--argument-constraints--flagify-parameters`](attributes.md#arg--argument-constraints--flagify-parameters) | just generates `--help`/`--usage` from the schema for free |
| Assuming `{{ x }}` works inside string literals | It only works in recipe bodies (and format strings `f'…{{x}}…'` 1.44.0+) — see [`expressions.md`](expressions.md) | `'foo {{ x }}'` is the literal characters `foo {{ x }}` |
| `-` prefix on every line "to be safe" | Only on lines you genuinely want to ignore failures of; pair with `set -e` in shebang recipes — see [`scripts.md`](scripts.md) | `-` swallows real errors, hiding bugs |
| Forgetting `{{{{ }}}}` when emitting a literal `{{ ... }}` | Quadruple braces `{{{{` → `{{`; matching `}}}}` → `}}` — see [`expressions.md#3-string-interpolation-and-brace-escaping`](expressions.md#3-string-interpolation-and-brace-escaping) | An unmatched `}}` won't break parsing, but matching is clearer and survives refactors |
| `set windows-powershell` | `set windows-shell := ["pwsh", "-NoLogo", "-Command"]` — see [`settings.md`](settings.md) | Deprecated; `windows-shell` is the modern replacement |
| Recipe that takes a path arg but does NOT have `[no-cd]` | Add `[no-cd]` — see [`attributes.md#no-cd`](attributes.md#no-cd) | The user names paths relative to their cwd, not the justfile's directory |
| Sequential deps for independent work (`check: lint; check: format; check: audit` chained) | `[parallel]` on the aggregator recipe — see [`attributes.md#parallel`](attributes.md#parallel) | Free concurrency when deps don't share state |
