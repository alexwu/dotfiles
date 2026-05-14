# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Experimental Neovim configuration using Neovim 0.12+ nightly features:
- **Builtin plugin manager**: Uses `vim.pack` (Neovim's native plugin manager) instead of lazy.nvim/packer
- **Per-plugin layout**: `plugin/<name>.lua` per plugin (one `vim.pack.add` + `setup` per file). `init.lua` holds foundations only (~480 lines).
- **Manual treesitter setup**: No `treesitter-modules.nvim`. Uses `vim.treesitter.start` + `nvim-treesitter.install` directly per the plugin author's own README recommendation.
- **`vim.lsp.config()` + `vim.lsp.enable()`**: New builtin LSP config API. Per-server overrides live in `after/lsp/<name>.lua`.

## Requirements

- Neovim 0.12+ nightly build
- tree-sitter CLI (auto-installed by `plugin/nvim-treesitter.lua` via brew/scoop/npm)
- `~/Code/neovim/plugins/bu/` checkout of the bu library (alexwu/bombeelu-tils on GitHub) — required by `bombeelu.autocmds`, `bombeelu.visual-surround`, and global keymaps in `init.lua`. `init.lua` rtp-prepends this path.

## Plugin Management with vim.pack

Each plugin lives in its own `plugin/<name>.lua`. Each file:
1. (Optional) cond check using `bombeelu.utils.not_vscode` or similar
2. `vim.pack.add({ { src = gh("user/repo"), ... } })` — `gh()` is a global helper from `init.lua`
3. `require("...").setup({...})`
4. Plugin-specific keymaps, commands, autocmds

**No `vim.g.loaded_<x>` guards on plugin specs** — `vim.pack.add` is idempotent and most setup() calls overwrite via augroups (`clear=true`) or `keymap.set` which replace not duplicate. Re-sourcing during dev iteration is desirable, not a footgun. Reserve guards for `plugin/bombeelu-<name>.lua` auto-loads (where re-running setup() would duplicate side effects).

### Loading order

`plugin/*.lua` files source alphabetically after `init.lua` finishes. Three numeric-prefixed exceptions guarantee correct ordering:
- `plugin/00-lush.lua` — colorscheme dependency, must come first
- `plugin/01-snazzy.lua` — sets the colorscheme
- `plugin/02-snacks.lua` — Snacks loaded early so any other plugin's setup() can rely on `Snacks` being globally available

Other ordering deps work via natural alphabetical order: `mason` < `mason-lspconfig` < `nvim-lspconfig`.

### URL helpers

Defined globally in `init.lua` and exposed via `_G`:
- `gh("user/repo")` → `"https://github.com/user/repo"`
- `gl("user/repo")` → GitLab
- `cb("user/repo")` → Codeberg

### Adding a New Plugin

1. Create `plugin/<name>.lua`:
```lua
-- Optional cond
local utils = require("bombeelu.utils")
if not utils.not_vscode then return end

vim.pack.add({ { src = gh("author/plugin-name") } })
require("plugin-name").setup({ ... })
```

2. Run `:Pack update` to install.

### Plugin Management Commands

```vim
:Pack update [name]   " Update plugin(s)
:Pack info [name]     " Show plugin info (path, rev, branches, tags)
:Pack get [name]      " Same as info
:checkhealth vim.pack " Verify plugin state
```

## Configuration Architecture

### `init.lua` (foundations only)

Sections, in order:
1. **`vim.loader.enable()`** (line 1, ~30% startup speedup per echasnovski's vim.pack guide)
2. Monkey patch for vim.system nil stdout/stderr bug in nightly builds
3. `<leader>` set to space
4. `M.set` keymap helper, `_G.set = M.set`
5. **bu rtp prepend** for `~/Code/neovim/plugins/bu`
6. Platform helpers via `require("bombeelu.utils")` (is_mac, is_vscode, invert, not_vscode)
7. URL helpers (`gh`/`gl`/`cb`) and `is_active`, exposed as globals for plugin/* files
8. **PackChanged hooks** (currently the fff.nvim binary build) — must register before any `plugin/*.lua` calls `vim.pack.add`
9. Vim options (with `ch=2`, MenuPopup cleanup autocmd, yank highlight, completeopt, etc.)
10. `vim.diagnostic.config()`
11. Global keymaps: j/k smart, indent, ESC, save, F2/F3, alt-BS, Q, ]t/[t, scroll-half, treesitter `<CR>`/`<BS>`, `<C-y>` inline completion, gd/grr/gri/grt/grx/gra LSP keymaps, `K` smart hover dispatcher, `<A-o>`/`<A-O>` via `bu.keys.o/O`
12. Custom commands (`Qa`, `Wq`, `W`)
13. `:Pack` user command (Lazy.nvim-style management UI)

### `lua/bombeelu/` modules

| Module | Description |
|---|---|
| `autocmds` | LazyVim-derived autocmds: checktime, resize_splits, last_loc, close_with_q, man_unlisted, wrap_spell, json_conceal, auto_create_dir |
| `git` | Tiered base branch detection (PR cache → reflog → merge-base → default). Async `gh` PR cache on BufEnter |
| `lspinfo` | Floating-window `:LspInfo` reimplementation (the original was removed from nvim-lspconfig) |
| `neotest` | `:Test` command + jump keymaps (wired by `plugin/neotest.lua`) |
| `neovide` | Neovide GUI options + `<D-*>` clipboard keymaps. Guarded by `vim.g.neovide` |
| `utils` | Platform detection (is_mac, is_vscode, is_windows, invert, not_vscode) |
| `visual-surround` | Visual-mode surround shortcuts: `(`/`{`/`[`/`q`/`'`/`` ` ``/`t` |
| `vscode` | VSCode-embedded-Neovim keymaps. Guarded by `vim.g.vscode` |

### `plugin/bombeelu-*.lua` auto-loads

Each module with side effects (autocmds, commands, keymaps) has an auto-load entry guarded by `vim.g.loaded_bombeelu_<name>`. Lightweight entries (e.g. `:LspInfo`) defer the main module `require` until invocation.

`bombeelu.neotest` is wired from `plugin/neotest.lua` (after `require("neotest").setup(...)`) rather than from a `plugin/bombeelu-neotest.lua` — since `b` < `n` alphabetically, the bombeelu auto-load would source before neotest is on rtp.

### `after/lsp/` overrides

Per-server `vim.lsp.config()` overrides. Auto-loaded by Neovim's runtime and deep-merged with nvim-lspconfig's shipped `lsp/<name>.lua`. Add a new server here:

1. Create `after/lsp/<server>.lua` returning the config table
2. Add the server name to the `servers` list in `plugin/nvim-lspconfig.lua`

## Custom Commands

```vim
:Pick [picker-name]  " Unified picker interface (defaults to "files", supports all Snacks pickers)
:Format [formatter]  " Format buffer with configured formatter (or specific one)
:Commit              " Smart commit (tinygit) — staged or all changes
:Pack update [name]  " Update plugin(s)
:Pack info [name]    " Show plugin info
:Test                " Run nearest test (bombeelu.neotest)
:W / :Wq / :Qa       " Auto-corrected to lowercase
```

## Treesitter (manual setup, no wrapper plugin)

Per the `treesitter-modules.nvim` README, post-0.12 incremental selection is native via `an`/`in` keymaps. `plugin/nvim-treesitter.lua` does the rest manually via `vim.treesitter.start(buf, lang)` (highlight), `vim.treesitter.foldexpr()` (fold), `nvim-treesitter.indentexpr()` (indent), and a FileType autocmd that auto-installs missing parsers.

The `<CR>`/`<BS>` bindings in `init.lua` use `vim.treesitter._select` (internal) with an LSP fallback — coexists with native `an`/`in`.

## Lazy-load Patterns (DirChanged-deferred)

Some plugins should only load when the cwd contains a relevant project marker:
- `plugin/nvim-vtsls.lua` — only loads when `tsconfig.json` is found
- `plugin/xcodebuild.lua` — only loads when `*.xcodeproj`, `*.xcworkspace`, or `Package.swift` is found

Each uses a `loaded` flag closure + a `DirChanged` autocmd to (re)check the marker. Keymap registration happens inside the `check()` function only after `vim.pack.add` returns. This mirrors the main lazy.nvim config's `init = function() ... require("lazy").load() end` pattern, but uses `vim.pack.add` (sync, idempotent) instead.

## File Structure

```
init.lua                           # ~480 lines: foundations only
filetype.lua                       # custom filetype detection (identical to dot_config/nvim/)
queries/                           # custom treesitter queries (identical to dot_config/nvim/)
lua/bombeelu/                      # custom modules (autocmds, git, lspinfo, neotest, neovide, utils, visual-surround, vscode)
plugin/                            # plugin specs (one per plugin) + bombeelu-* auto-loads
  00-lush.lua / 01-snazzy.lua / 02-snacks.lua    # numeric prefix for early load
  bombeelu-*.lua                   # auto-loads for lua/bombeelu/ modules
  <plugin>.lua × ~50               # vim.pack.add + setup per plugin
after/lsp/                         # per-server LSP config overrides
```

## Development Workflow

1. **Edit config** under `dot_config/pack-nvim/` (chezmoi-managed source)
2. **`chezmoi apply`** to deploy to `~/.config/pack-nvim/`
3. **`stylua dot_config/pack-nvim/`** to format Lua files (mandatory before commit)
4. **Launch**: `NVIM_APPNAME=pack-nvim nvim` (alias `envim`)
5. **Update plugins**: `:Pack update`
6. **Install LSP servers**: `:Mason`
7. **Health check**: `:checkhealth vim.pack`

## Reference

- [echasnovski — A guide to vim.pack](https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack)
- Main config (lazy.nvim) at `dot_config/nvim/` — feature-parity reference for porting
