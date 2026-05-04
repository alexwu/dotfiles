---
paths:
  - "dot_gitconfig"
  - "private_Library/private_Application Support/lazygit/**"
---

# Git

## Git
- Pager: **delta** (side-by-side, with decorations theme)
- Diff tool: **difftastic** (`git difftool` uses `difft`)
- Default branch: `main`, branch sort: `-committerdate`
- GPG signing off by default (`commit.gpgsign = false`)
- SSH signing program: 1Password (`op-ssh-sign`)
- LFS enabled
- `core.fsmonitor = false`

## Lazygit
- Config: `private_Library/private_Application Support/lazygit/config.yml`
- Editor preset: nvim
- `autoFetch: false`, log order: topo-order
- Theme: dark with green inactive borders
