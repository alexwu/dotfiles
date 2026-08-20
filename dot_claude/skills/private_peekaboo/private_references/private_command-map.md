# Peekaboo command map

Stable category map of the CLI. **Categories and command names are durable; flags move between releases** — run `peekaboo <command> --help` for authoritative flags and `peekaboo learn` for the full agent guide. Most commands accept `--json` (alias `--json-output`); parse it with `jaq`. `peekaboo tools` lists the MCP/agent catalog; some agent tools have dedicated CLI wrappers (`browser`, `inspect-ui`).

## Vision & capture

| Command | What it does |
|---------|--------------|
| `see` | Capture an annotated UI map; returns element IDs + a snapshot ID; optional `--analyze` AI pass. The front door for interaction. |
| `image` | Save raw PNG/JPG of screens, windows, or menu-bar regions. `--mode screen\|window\|area`, `--region`, `--analyze`. |
| `capture` | Long-running capture: `capture live` (adaptive frames), `capture action` (records around a child command), `capture video`. |
| `inspect-ui` | Read accessible UI text / controls without a screenshot (wraps the `inspect_ui` MCP tool). |
| `list` | `apps`, `windows`, `screens`, `menubar`, `permissions`. |
| `tools` | List the MCP/agent tool catalog (`--verbose`, `--json`). |
| `learn` | Print the complete agent guide (system prompt, tool catalog, signatures). |
| `clean` | Remove snapshot caches by ID/age/all (`--dry-run`). |
| `run` | Execute `.peekaboo.json` scripts (`--output`, `--no-fail-fast`). |
| `sleep` | Millisecond pause between steps. |
| `completions` | Generate zsh/bash/fish completions. |
| `config` | `init`, `show`, `edit`, `validate`, providers/credentials/models. |
| `daemon` | Headless daemon: live window tracking + in-memory snapshots (`start`/`stop`/`status`). |
| `permissions` | `status` (default), `grant`, Event-Synthesizing request helpers. |

## Interaction

| Command | What it does |
|---------|--------------|
| `click` | Target by element ID / query / coords, with smart waits and focus helpers. `--on`, `--coords`, `--snapshot`, `--input-strategy`, `--no-auto-focus`. |
| `type` | Send text + control keys. `--clear`, `--delay`, tab counts. |
| `press` | Fire named `SpecialKey` sequences with repeat counts (`return`, `tab`, `escape`, arrows…). There is no `key` command. |
| `hotkey` | Emit a modifier combo in one shot, e.g. `cmd,shift,t`. |
| `paste` | Atomically set clipboard → Cmd+V → restore previous clipboard. |
| `scroll` | Directional scroll with optional element target and smooth mode. |
| `swipe` | Gesture-style drag between IDs/coords (`--duration`, `--steps`). |
| `drag` | Drag-and-drop across elements/coords/Dock with modifiers. |
| `move` | Position the cursor at coords / element center / screen center. |
| `perform-action` | Invoke a raw accessibility action (`AXPress`, `AXSetValue`) on an element — the cleanest UIAX smoke test. |
| `set-value` | Set an element's value directly. |

## Windows, menus, apps, spaces

| Command | What it does |
|---------|--------------|
| `window` | `close`, `minimize`, `maximize`, `move`, `resize`, `set-bounds`, `focus`, `list`. |
| `space` | `list`, `switch`, `move-window` for virtual desktops. |
| `menu` | `click`, `click-extra`, `list`, `list-all` for app menus + menu extras. |
| `menubar` | `list` / `click` status-bar icons by name or index. |
| `app` | `launch`, `quit`, `relaunch`, `hide`, `unhide`, `switch`, `list`. `launch` takes repeatable `--open <url\|path>`, `--wait-until-ready`, `--no-focus`. |
| `open` | Enhanced `open` honoring `--app`/`--bundle-id`, `--wait-until-ready`, `--no-focus`, JSON output. |
| `dock` | `launch`, `right-click`, `hide`, `show`, `list` Dock items. |
| `dialog` | `click`, `input`, `file`, `dismiss`, `list` system dialogs. |
| `visualizer` | Fire the visual-feedback smoke suite to verify Peekaboo.app overlays. |

## Automation & integrations

| Command | What it does |
|---------|--------------|
| `agent` | Natural-language automation with dry-run planning, resume, model overrides. |
| `browser` | CLI wrapper for the browser MCP tool: Chrome status/connect/navigate/snapshot/click/fill/type/console/network/screenshot/trace. |
| `mcp` | `serve`, `list`, `add`, `remove`, `enable`, `disable`, `info`, `test`, `call` for MCP workflows. |

For structured output, pass `--json`; for deterministic multi-step flows, author a `.peekaboo.json` and run it via `peekaboo run`.
