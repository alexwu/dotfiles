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
├── lua/
│   ├── options.lua                   # Vim options and basic autocmds
│   ├── mappings.lua                  # Global keymaps
│   └── plugins/                      # lazy.nvim plugin specs (auto-imported)
│       ├── colorscheme.lua           # Colorscheme plugin
│       ├── completion.lua            # Completion engine (blink.cmp)
│       ├── editor.lua                # Editor utilities (mini.*, conform, gitsigns, etc.)
│       ├── lsp.lua                   # LSP core: mason, lspconfig, diagnostics, generic servers
│       ├── picker.lua                # File/buffer pickers (fff.nvim, snacks)
│       ├── treesitter.lua            # Treesitter config and modules
│       ├── ui.lua                    # UI plugins (snacks.nvim, lualine, etc.)
│       └── lang/                     # Language-specific LSP configurations
│           ├── python.lua            # basedpyright + ruff
│           ├── ruby.lua              # ruby_lsp + sorbet
│           ├── typescript.lua        # vtsls + denols + biome
│           └── web.lua               # eslint + tailwindcss + html
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

**Generic servers** (no custom config needed): Add to `lsp.lua` in the nvim-lspconfig config function:

```lua
vim.lsp.enable("server_name")
```

**Servers with custom settings**: Add to `lsp.lua` or a `lang/*.lua` file:

```lua
vim.lsp.config("server_name", {
  settings = { ... },
  root_markers = { ... },
})
vim.lsp.enable("server_name")
```

**Language-specific servers**: Create or edit a file in `lua/plugins/lang/`. Use `ft` for lazy-loading by filetype:

```lua
return {
  {
    "neovim/nvim-lspconfig",
    ft = { "language_name" },
    config = function()
      vim.lsp.config("server_name", { ... })
      vim.lsp.enable("server_name")
    end,
  },
}
```

Mason auto-enables all installed servers except those in the exclude list (`harper-ls`, `lua_ls`).

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

### snacks.nvim as Hub

[snacks.nvim](https://github.com/folke/snacks.nvim) provides multiple UI features from a single plugin:
- Statuscolumn, terminal toggles, dashboard
- Built-in pickers (used as fallback)
- Input prompts (used by inc-rename)

### Unified Picker Interface

The `:Pick` command provides a consistent picker interface that works with both fff.nvim and Snacks.nvim pickers. Defaults to file picker, supports all Snacks picker types.

### fff.nvim + Snacks Pickers

Primary file/grep picker is fff.nvim. Snacks pickers serve as fallback and provide additional picker types (LSP symbols, diagnostics, etc.).
