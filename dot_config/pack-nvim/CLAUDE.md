# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Experimental minimal Neovim configuration using Neovim 0.12+ nightly features:
- **Builtin plugin manager**: Uses `vim.pack` (Neovim's new native plugin manager) instead of lazy.nvim/packer
- **Breaking changes**: Based on nvim-treesitter's main branch with breaking changes
- **Single-file config**: Entire configuration in `init.lua` (~1400 lines)

## Requirements

- Neovim 0.12+ nightly build
- tree-sitter CLI (auto-installed on first run via brew/scoop/npm)

## Plugin Management with vim.pack

This config uses Neovim's new builtin `vim.pack` API instead of external plugin managers.

### Key Concepts

1. **Plugin specs** are defined as a Lua table in `init.lua:234-289`:
```lua
local plugins = {
  { src = gh("user/repo"), name = "plugin-name", version = "main" },
  { src = gh("user/repo"), cond = is_mac },
}
```

2. **URL helpers**: `gh(repo)`, `gl(repo)`, `cb(repo)` generate full URLs from "user/repo" format

3. **Conditional loading**: Use `cond` field with boolean or function:
   - `cond = is_mac` - only on macOS
   - `cond = invert(is_vscode)` - skip in VSCode
   - Helper functions: `is_mac()`, `is_windows()`, `is_vscode()`, `invert(fn)`

4. **Plugin loading**: `vim.pack.add()` called once with all plugins (`init.lua:313`)

5. **Check if plugin is active**: Use `is_active("plugin-name")` helper function

### Plugin Management Commands

```bash
# Update all plugins
:Pack update

# Update specific plugin
:Pack update <plugin-name>

# View plugin info (opens split with details)
:Pack info [plugin-name]
:Pack get [plugin-name]
```

## Configuration Architecture

All configuration is in `init.lua`, organized into sections with clear separators:

1. **Monkey patches** (lines 5-38): Workarounds for nightly bugs
2. **Utils** (lines 41-61): Helper function `M.set()` for keymaps
3. **Options** (lines 63-158): Vim options and basic autocmds
4. **Plugin installation** (lines 160-313): `vim.pack.add()` with plugin specs
5. **Plugin configurations** (lines 315+): Each plugin has dedicated section

### Adding a New Plugin

1. Add to `plugins` table:
```lua
{ src = gh("user/plugin"), version = "main" }
```

2. Add configuration section after other plugin configs:
```lua
-- ============================================================================
-- PLUGIN-NAME CONFIGURATION
-- ============================================================================

require("plugin-name").setup({})
```

3. Run `:Pack update` to install

### Key Architectural Patterns

**Conditional plugin loading**: Many plugins skip loading in VSCode using `cond = invert(is_vscode)`. This allows the same config to work in both Neovim and VSCode Neovim.

**LSP configuration**: Uses new `vim.lsp.config()` + `vim.lsp.enable()` API (lines 886-973) instead of lspconfig's `.setup()`.

**Unified picker interface**: Custom `:Pick` command (lines 547-614) that works with both fff.nvim and Snacks.nvim pickers, providing a consistent interface regardless of which is active.

**Helper functions for platform detection**: `is_mac()`, `is_windows()`, `is_vscode()` used throughout for conditional behavior.

## Custom Commands

### File Pickers
```vim
:Pick [picker-name]  " Unified picker interface
                     " defaults to 'files', supports all Snacks pickers
```

### Formatting
```vim
:Format              " Format buffer with configured formatter
:Format prettier     " Format with specific formatter
<F8> / gq            " Format buffer (normal mode)
<F8>                 " Format buffer (insert mode)
```

### Git
```vim
:Commit              " Smart commit (tinygit) - commits staged or all changes
```

### Plugin Management
```vim
:Pack update [name]  " Update plugin(s)
:Pack info [name]    " Show plugin info
```

### Common typo fixes
```vim
:W / :Wq / :Qa       " Auto-corrected to lowercase
```

## Treesitter

Using nvim-treesitter **main branch** (breaking changes from v1.0):
- Auto-installs missing parsers on buffer enter (`auto_install = true`)
- Uses `treesitter-modules.nvim` for configuration
- Install parsers: `:TSInstall <language>`

## LSP Setup

This config uses the **new builtin LSP configuration API** (`vim.lsp.config()` + `vim.lsp.enable()`):

```lua
vim.lsp.config("server_name", {
  settings = { ... }
})
vim.lsp.enable("server_name")
```

Enabled servers (lines 886-973):
- TypeScript: `vtsls` or `denols` (based on root markers)
- Python: `basedpyright` + `ruff`
- Web: `html`, `tailwindcss`, `eslint`, `biome`
- Others: `yamlls`, `taplo`, `zls`, `markdown_oxide`, `sourcekit`, `gdscript`, `sqruff`, `typos_lsp`

Mason auto-enables all installed servers except: `harper-ls`, `lua_ls`.

## File Structure

```
init.lua       - Entire configuration (1400+ lines)
filetype.lua   - Custom filetype detection
```

## Development Workflow

1. **Edit config**: Modify `init.lua`
2. **Reload**: `:restart` or `:source %`
3. **Update plugins**: `:Pack update`
4. **View plugin info**: `:Pack info`
5. **Install LSP servers**: `:Mason`
6. **Install treesitter parsers**: `:TSInstall <lang>`

## Important Implementation Details

### Keymap Helper
The `M.set()` function accepts single or multiple mappings:
```lua
set("n", { "<C-s>", "<D-s>" }, vim.cmd.write, { desc = "Save file" })
```

### Custom Scroll Implementation
Custom half-page scroll (lines 724-745) that respects buffer boundaries instead of using `<C-d>`/`<C-u>`.

### Snacks.nvim Integration
Many features depend on Snacks.nvim:
- Statuscolumn
- Terminal toggles
- Built-in pickers
- Input prompts (inc-rename uses "snacks" input_buffer_type)

Check if Snacks is active with `is_active("snacks.nvim")` before calling Snacks features.

### Folding Configuration
Uses treesitter-based folding:
- `foldmethod = "expr"` with treesitter
- `foldlevel = 99` (all folds open by default)
- Custom fillchars for modern fold icons

## Common Patterns

### Adding Keymaps
```lua
set("n", "<leader>x", function() ... end, { desc = "Description" })
set({ "n", "v" }, "key", "command", { silent = true })
```

### Checking Plugin Status
```lua
if is_active("plugin-name") then
  -- Plugin-specific code
end
```

### Formatter Configuration
Add formatters in `conform.nvim` setup (lines 752-786):
```lua
formatters_by_ft = {
  lua = { "stylua" },
  typescript = { "biome", "prettier", stop_after_first = true },
}
```

## Known Issues

- **vim.system bug**: Lines 5-38 contain commented monkey patch for nil stdout/stderr bug in nightly builds
- **nvim-treesitter main branch**: Breaking changes from v1.0, may have instability
