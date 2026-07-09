# Browser QA with playwright-cli inside the tart guest

`@playwright/cli` (microsoft/playwright-cli — the agentic, session-based CLI; NOT `npx playwright`)
running inside the guest, driven from the host one SSH call per command. Verified working 2026-07-09
(v0.1.17, chrome-for-testing 149, macOS 26.5 guest).

**Why this shape:** the session daemon lives in the guest and SURVIVES across separate SSH
connections — open a page in one SSH call, `find`/`click`/`screenshot` it in later ones. Each
command is a stateless one-liner from the host's perspective; the browser state persists in the VM.

## One-time provisioning (persists in the VM disk)

```bash
# guest has node/npm at /opt/homebrew/bin (Cirrus image ships them)
export PATH=/opt/homebrew/bin:$PATH
npm install -g @playwright/cli@latest
playwright-cli install-browser chrome-for-testing
```

## Gotchas (all hit live)

- **Default browser channel is branded `chrome`**, which the guest lacks — every `open` needs
  `--browser=chromium` (maps to the installed chrome-for-testing), or a `.playwright/cli.config.json`
  with `{"browser": {"browserName": "chromium"}}` in the working dir to make it the default.
- `export PATH=/opt/homebrew/bin:$PATH` first in every SSH call — non-interactive PATH misses node,
  and playwright-cli's daemon spawn resolves node from PATH (upstream issue playwright-mcp#1430).
- Run from a consistent cwd in the guest (e.g. `~/pwtest`) — snapshots/screenshots land in
  `.playwright-cli/` relative to the cwd, and the session registry is workspace-scoped.
- Headed mode (`open --headed`) works — the guest has a real Aqua session. Headless is the default
  and fine for most QA; headed + a peekaboo `image --mode screen` gives a desktop-level visual.

## Verified drive loop

```bash
SSHQ() { sshpass -p admin ssh $SSH_OPTS admin@$IP "export PATH=/opt/homebrew/bin:\$PATH; cd ~/pwtest; $*"; }

SSHQ playwright-cli open https://example.com --browser=chromium   # SSH call 1: opens session daemon
SSHQ playwright-cli find '"Example Domain"'                       # SSH call 2: same browser, returns refs
SSHQ playwright-cli click e6                                      # SSH call 3: click by ref → navigates
SSHQ playwright-cli screenshot --filename=/tmp/shot.png
SSHQ playwright-cli close                                         # tidy: kill the session daemon
```

`snapshot` / `find` return element refs (`e6`) usable in `click`/`fill`/`check`; CSS selectors and
`getByRole(...)` locators also work. `playwright-cli list` shows live sessions; `kill-all` is the
hammer if a daemon wedges. Named sessions via `-s=<name>` isolate parallel flows.

## Authenticated flows (work QA)

Cookies/localStorage live in the session (in-memory by default; `--persistent` writes the profile to
disk so logins survive browser restarts). `state-save`/`state-load <file>` snapshot auth state
explicitly. Log in once by driving the login form, save state, load it in later runs.
