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

# Check formatting across the main languages without writing (non-zero on drift).
fmt-check:
    shfmt -d .
    fd -e nim . -X nph --check
    stylua -s --check .
    rumdl check .
