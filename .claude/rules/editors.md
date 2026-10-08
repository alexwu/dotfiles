---
paths:
  - "dot_config/nvim/**"
  - "dot_config/pack-nvim/**"
  - "dot_config/neovide/**"
---

# Editors

## Neovim
- Primary config: `dot_config/pack-nvim/` — uses `vim.pack` (builtin plugin manager), one `plugin/<name>.lua` per plugin, targets Neovim 0.12+ nightly, has its own `CLAUDE.md`. `dot_zshrc` exports `NVIM_APPNAME=pack-nvim`, so plain `nvim` runs it
- Previous config: `dot_config/nvim/` — lazy.nvim, has its own `CLAUDE.md`
- Launch the previous one: `envim` (alias for `NVIM_APPNAME=nvim nvim`)
- Dev plugins load from `~/Code/neovim/plugins/` (patterns: `alexwu`)
- Colorscheme: **snazzy** (`alexwu/nvim-snazzy` + `rktjmp/lush.nvim`)
- Formatter: Lua files use **stylua** — always run before committing nvim config changes

## Neovide
- Config: `dot_config/neovide/config.toml`
- Font: Fira Code + FiraCode Nerd Font, size 14
- `NEOVIDE_FORK=1` and `NEOVIDE_MULTIGRID=true` set in zshrc
