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

### Bot-detection-gated sites (Cloudflare Turnstile etc.) — verified 2026-07-09

Playwright-launched chromium / chrome-for-testing gets fingerprinted and hard-blocked. The stack
that works: install REAL Chrome in the guest (`brew install --cask google-chrome`, then
`sudo xattr -dr com.apple.quarantine "/Applications/Google Chrome.app"`), launch it yourself —

```bash
open -n "/Applications/Google Chrome.app" --args --user-data-dir=$HOME/.qa-chrome \
  --remote-debugging-port=9223 --no-first-run --no-default-browser-check <URL>
```

— then `playwright-cli attach --cdp=http://localhost:9223`. Genuine fingerprint + the guest's
NAT egress (same public IP as the host) sails past the challenge.

**Migrating an authenticated session host→guest: NEVER copy the Chrome profile directory.**
Cookies are encrypted with the host's "Chrome Safe Storage" login-keychain key; the guest can't
decrypt them and silently drops every cookie (you land logged-out with no error). Instead:
`state-save` on the host browser over CDP (cookies export decrypted) → scp → `state-load` in the
guest → cookies re-persist under the guest's own keychain and survive VM restarts. Delete the
state file on both sides afterwards — it holds live session cookies.

Worked end-to-end example (Turnstile-gated Shopify admin, cross-origin OOPIF, screenshots):
the Cleverific `qa-cleverific-browser` skill — `references/qa-in-tart-vm.md` and the
`scripts/qa-vm.just` executable justfile.
