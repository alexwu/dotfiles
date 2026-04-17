# CLAUDE.md

This file provides guidance to Claude Code when working with this Neovim configuration.

## Project Overview

Minimal Neovim configuration using **lazy.nvim** as the plugin manager. Targets **Neovim 0.12+ nightly**. Uses the new builtin `vim.lsp.config()` + `vim.lsp.enable()` API for LSP configuration. Managed via chezmoi as dotfiles.

## Directory Structure

```
dot_config/nvim/
├── init.lua                          # Entry point: sets leader, bootstraps lazy.nvim, loads options/mappings
├── filetype.lua                      # Custom filetype detection
├── stylua.toml                       # StyLua formatter config for Lua files
├── .emmyrc.json                      # EmmyLua LSP config
├── .chezmoiignore                    # Chezmoi ignore rules
├── after/
│   └── lsp/                          # Per-server config overrides (merged by Neovim runtime)
│       ├── basedpyright.lua
│       ├── biome.lua
│       ├── denols.lua
│       ├── eslint.lua
│       ├── ruby_lsp.lua
│       ├── sorbet.lua
│       ├── sqruff.lua
│       ├── tailwindcss.lua
│       ├── typos_lsp.lua
│       └── vtsls.lua
├── plugin/                           # Auto-loaded entry points (sourced at startup via rtp)
│   ├── bombeelu-git.lua
│   ├── bombeelu-lspinfo.lua          # Lazy-registers :LspInfo command
│   ├── bombeelu-neovide.lua          # Guarded by vim.g.neovide
│   ├── bombeelu-visual-surround.lua
│   └── bombeelu-vscode.lua           # Guarded by vim.g.vscode
├── lua/
│   ├── options.lua                   # Vim options and basic autocmds
│   ├── mappings.lua                  # Global keymaps
│   ├── bombeelu/                     # Custom modules (bombeelu namespace)
│   │   ├── git.lua                   # Git base branch detection (tiered: PR cache → reflog → merge-base → default)
│   │   ├── lspinfo.lua               # :LspInfo floating window implementation
│   │   ├── neotest.lua               # Neotest command + jump keymaps (currently orphaned)
│   │   ├── neovide.lua               # Neovide opacity, animations, <D-*> clipboard keymaps
│   │   ├── utils.lua                 # Platform detection (is_mac, is_vscode, not_vscode, invert)
│   │   ├── visual-surround.lua       # Visual selection surround (parens, quotes, brackets, tags)
│   │   └── vscode.lua                # VSCode-embedded-Neovim keymaps
│   └── plugins/                      # lazy.nvim plugin specs (auto-imported)
│       ├── colorscheme.lua           # Colorscheme plugin
│       ├── completion.lua            # Completion engine (blink.cmp)
│       ├── editor.lua                # Editor utilities (mini.*, conform, gitsigns, etc.)
│       ├── linter.lua                # nvim-lint with debounce, fallback, conditional linters
│       ├── lsp.lua                   # LSP core: mason, lspconfig, diagnostics, servers list
│       ├── picker.lua                # File/buffer pickers (fff.nvim, snacks)
│       ├── treesitter.lua            # Treesitter config and modules
│       ├── ui.lua                    # UI plugins (snacks.nvim, lualine, etc.)
│       └── lang/                     # Language/framework-specific plugins (NOT contributions to shared plugins)
│           ├── just.lua              # nvim-justice
│           ├── python.lua            # (stub — awaiting python-specific plugins)
│           ├── rust.lua              # rustaceanvim (manages rust_analyzer internally)
│           └── typescript.lua        # (stub — awaiting ts-specific plugins)
└── queries/                          # Custom treesitter queries
    ├── bash/injections.scm
    ├── html/injections.scm
    ├── just/injections.scm
    ├── lua/highlights.scm
    ├── ruby/highlights.scm
    ├── ruby/injections.scm
    ├── rust/injections.scm
    └── toml/injections.scm
```

## Plugin Management

This config uses [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management. Plugins are auto-imported from the `lua/plugins/` directory (including subdirectories like `lang/`).

- `:Lazy` opens the lazy.nvim UI to view, update, install, and manage plugins
- `:Lazy update` updates all plugins
- `:Lazy sync` installs missing plugins and removes unused ones

### Adding a New Plugin

Create or edit a spec file in `lua/plugins/`. Each file returns a table of plugin specs:

```lua
return {
  {
    "author/plugin-name",
    event = "VeryLazy",           -- lazy-load on event
    opts = { ... },               -- passed to plugin.setup()
  },
}
```

Multiple specs can reference the same plugin (e.g., `neovim/nvim-lspconfig` appears in `lsp.lua` and each `lang/*.lua` file). lazy.nvim merges them.

## Adding a New LSP Server

1. Add the server name to the `servers` list in the `neovim/nvim-lspconfig` spec in `lsp.lua` (alphabetical).
2. If the server needs custom settings/root_markers/cmd, create `after/lsp/<server>.lua` returning the config table. Neovim deep-merges it with nvim-lspconfig's shipped `lsp/<server>.lua` automatically.
3. Servers that bundle their own LSP management (e.g. rustaceanvim for rust_analyzer) should NOT be added to the `servers` list — they conflict.

The `neovim/nvim-lspconfig` spec uses `opts = { servers = {...} } + opts_extend = { "servers" } + config = function(_, opts)` specifically to avoid the deprecated `require("lspconfig").setup(opts)` auto-call. Keep that structure — removing the `config` function triggers the deprecated path.

Mason auto-enables installed servers except those in the exclude list (`harper_ls`, `lua_ls`).

## Dev Plugins

Local dev plugins load from `~/Code/neovim/plugins/` (configured in init.lua `dev.path`).
Plugins with `dev = true` and matching `patterns = { "alexwu" }` resolve to this path.
The `bu` library (`alexwu/bu`) provides `bu.keys` and `bu.nvim.repeatable` used in mappings.

## Custom Modules (`lua/bombeelu/`)

Each module with side effects (autocmds, commands, keymaps) has an auto-loaded entry point in `plugin/bombeelu-<name>.lua` guarded by `vim.g.loaded_bombeelu_<name>`. Lightweight entries (e.g. `:LspInfo`) defer the main module `require` until invocation.

- **`bombeelu.git`**: Tiered base branch detection for diff pickers. Async PR cache on `BufEnter` (5-min TTL), cleared on `DirChanged`. Tiers: PR base → reflog → merge-base scan (top 20) → default branch fallback.
- **`bombeelu.visual-surround`**: Wraps visual selection in pairs. Keymaps: `(`, `{`, `[`, `q` (double quotes), `'`, `` ` ``, `t` (HTML tag prompt).
- **`bombeelu.lspinfo`**: Floating-window `:LspInfo` reimplementation (the original command was removed from nvim-lspconfig). Filters servers by current filetype.
- **`bombeelu.vscode`**: VSCode-embedded-Neovim keymaps. Guarded by `vim.g.vscode`.
- **`bombeelu.neovide`**: Neovide-specific `vim.g.*` options and `<D-*>` system-clipboard bindings. Guarded by `vim.g.neovide`.
- **`bombeelu.utils`**: Platform detection helpers. `utils.not_vscode` is used as `cond` on UI-heavy plugin specs.
- **`bombeelu.neotest`**: `:Test` command + jump keymaps. Currently **orphaned** (not wired up from any `plugin/` file).

## Adding a New Formatter

Add to the `formatters_by_ft` table in the conform.nvim spec in `editor.lua`:

```lua
formatters_by_ft = {
  newlang = { "formatter_name" },
  -- Use stop_after_first for fallback chains:
  typescript = { "biome", "prettier", stop_after_first = true },
}
```

## Key Commands

| Command       | Description                                      |
|---------------|--------------------------------------------------|
| `:Lazy`       | Open lazy.nvim plugin manager UI                 |
| `:Mason`      | Open Mason LSP/tool installer UI                 |
| `:Pick [name]`| Unified picker interface (files, grep, buffers)  |
| `:Format`     | Format current buffer with configured formatter  |
| `:Format name`| Format with a specific formatter                 |
| `:Commit`     | Smart git commit (tinygit)                       |
| `<leader>gg`  | Git diff picker vs base branch (Snacks)          |
| `<leader>gD`  | CodeDiff view vs base branch                     |
| `<leader>nd`  | Dismiss notifications (noice)                    |
| `<leader>nh`  | Notification history (noice)                     |
| `<leader>uh`  | Toggle inlay hints (Snacks.toggle)               |
| `<leader>ud`  | Toggle diagnostics (Snacks.toggle)               |
| `<leader>up`  | Toggle inline diagnostics (Snacks.toggle)        |

## lazy.nvim Spec Patterns

### `opts` vs `config`

- **`opts = { ... }`**: Passed directly to `require("plugin").setup(opts)`. Use for simple config.
- **`config = function() ... end`**: Full control over setup. Use when calling APIs beyond `.setup()`.

### Lazy Loading Triggers

- **`event`**: Load on Neovim event (`"VeryLazy"`, `"BufReadPre"`, `"LspAttach"`)
- **`cmd`**: Load on command (`:Mason`, `:Format`)
- **`keys`**: Load on keymap
- **`ft`**: Load on filetype (`{ "python" }`, `{ "typescript", "typescriptreact" }`)
- **`lazy = false`**: Load immediately at startup

### VSCode Conditional Loading

Plugins that should not load in VSCode's embedded Neovim use:

```lua
cond = function()
  return vim.g.vscode == nil
end
```

This pattern is used on UI-heavy plugins (diagnostics, statusline, etc.) that are irrelevant in VSCode.

## Custom Treesitter Queries

The `queries/` directory contains custom treesitter queries that override or extend the defaults:

- **`injections.scm`**: Define language injection rules (e.g., highlight SQL inside Ruby strings, Lua inside Neovim config TOML)
- **`highlights.scm`**: Custom syntax highlighting rules

Files are organized by language: `queries/<language>/<query_type>.scm`.

## Key Architectural Patterns

### New `vim.lsp` API

Uses Neovim 0.12+'s builtin LSP configuration instead of lspconfig's legacy `.setup()`:
- `vim.lsp.config("name", { ... })` to configure
- `vim.lsp.enable("name")` to activate
- Mason + mason-lspconfig auto-enables installed servers
- Per-server overrides live in `after/lsp/<name>.lua` (preferred) rather than inline `vim.lsp.config()` calls

### Lang Files Philosophy

`lua/plugins/lang/<name>.lua` is for **language/framework-specific plugins** (e.g. rustaceanvim, nvim-justice). Contributions to shared plugins (conform formatters, blink sources, nvim-lint linters) live in the main plugin spec, not a lang file. The mergeable `opts + opts_extend` structure is kept on shared plugins in case future needs arise, but lang files don't actively use it. LSP server names live in `lsp.lua`'s central `servers` list — do not put them in lang files.

### Plugin/ auto-load entries

Custom bombeelu modules expose themselves via `plugin/bombeelu-<name>.lua` files that Neovim sources automatically from the runtime path. Each file has a `vim.g.loaded_bombeelu_<name>` guard at the top. Command registration defers `require("bombeelu.<name>")` to invocation time so the full module only loads when used.

### snacks.nvim as Hub

[snacks.nvim](https://github.com/folke/snacks.nvim) provides multiple UI features from a single plugin:
- Statuscolumn, terminal toggles, dashboard
- Built-in pickers (used as fallback)
- Input prompts (used by inc-rename)
- `Snacks.toggle` for feature toggles with which-key integration, notifications, and state indicators

### Snacks.toggle for Feature Toggles

Prefer `Snacks.toggle` over plain keymaps for on/off features. It provides which-key state icons/colors and toggle notifications. Use built-in toggles where available (`Snacks.toggle.inlay_hints()`, `Snacks.toggle.diagnostics()`), and `Snacks.toggle.new()` for custom toggles (e.g., tiny-inline-diagnostic).

### Unified Picker Interface

The `:Pick` command provides a consistent picker interface that works with both fff.nvim and Snacks.nvim pickers. Defaults to file picker, supports all Snacks picker types.

### fff.nvim + Snacks Pickers

Primary file/grep picker is fff.nvim. Snacks pickers serve as fallback and provide additional picker types (LSP symbols, diagnostics, etc.).

## LSP Feature Gating

New LSP features are enabled conditionally in a single `LspAttach` autocmd in `lsp.lua`. Use `client:supports_method()` to gate features:

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/someFeature") then
      -- enable feature
    end
  end,
})
```

Currently gated: inlay hints (`textDocument/inlayHint`), linked editing range (`textDocument/linkedEditingRange`).

## Reference: Old Nightly Config

The previous nightly Neovim config lives at `github.com/alexwu/nvim` branch `nightly`. Useful as reference for porting features. Access via `gh api "repos/alexwu/nvim/contents/<path>?ref=nightly"`.
