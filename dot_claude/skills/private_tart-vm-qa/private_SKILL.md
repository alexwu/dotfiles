---
name: tart-vm-qa
description: Run GUI QA inside a headless tart macOS VM so the app under test never steals focus on the host. Use when asked to QA, smoke-test, screenshot, or drive any macOS .app or a browser flow "in the VM", "headless", "without stealing focus", "in the background", or via tart. Covers boot/deploy/drive over SSH, peekaboo GUI automation in the guest, and playwright-cli browser QA in the guest.
---

# Headless VM QA with tart

A tart macOS guest (`tahoe-base`, cloned from `ghcr.io/cirruslabs/macos-tahoe-base`) runs with **no host window** under `tart run --no-graphics`, yet still renders a full virtual display with an auto-logged-in Aqua session. Everything runs over SSH; the host keeps focus the entire time. Proven end-to-end 2026-07-09 (a native SwiftUI app + peekaboo + headed Chromium; same day: real Chrome + an authenticated, Turnstile-gated admin — see the playwright reference).

**Check the repo first:** a project may ship its own harness on top of this flow (a `qa:vm`-style task runner target, a project QA skill) — the repo's CLAUDE.md is the pointer. Prefer the project harness when one exists; the recipe below is the generic floor.

**Why permissions just work:** the Cirrus images pre-grant Accessibility, ScreenCapture, PostEvent, and AppleEvents to `/usr/libexec/sshd-keygen-wrapper` in TCC.db (SIP and Gatekeeper are disabled in the image). Any binary invoked over SSH inherits those grants — peekaboo, playwright, anything. No dialogs, no tccutil, no MDM.

## Host setup from scratch

All formulas, no casks (the only cask in the whole flow is real Chrome *inside* the guest — see the playwright reference):

```bash
brew install cirruslabs/cli/tart        # tart, from the Cirrus tap (repo now lives at openai/tart)
brew install sshpass                    # ONE use only: the first-contact login that installs the QA
                                        # key (see "SSH auth" below). Never drive the guest with it.
brew install steipete/tap/peekaboo      # for host-side GUI QA; guests brew-install their own copy
brew install playwright-cli             # homebrew-core; host install only needed to drive a HOST browser
                                        # (e.g. state-save for session migration) — in the GUEST install it
                                        # via npm instead: npm install -g @playwright/cli@latest
```

Newer Homebrew refuses third-party taps until trusted: if `brew install steipete/tap/peekaboo` errors with "untrusted tap", run `brew trust steipete/tap` first. If tons of daily VMs ever exhaust DHCP leases, the tart caveat has the `bootpd` lease-time fix (tart.run/faq).

Then pull the base image (~25 GB download, 50 GB sparse disk — one-time):

```bash
tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest tahoe-base
```

## The golden image (`qa-golden`)

`tart clone` is APFS copy-on-write — snapshotting a provisioned guest costs seconds and ~no disk. `qa-golden` (built 2026-07-09) is `tahoe-base` frozen right after provisioning, containing on top of the Cirrus base (which already ships brew, node/npm/npx, python, ruby):

- **peekaboo** at `/usr/local/bin/peekaboo` (scp'd from the host — `readlink -f` the brew symlink first)
- **`@playwright/cli`** global + its `chrome-for-testing` browser (`playwright-cli install-browser chrome-for-testing`)
- **playwright** (npm project at `~/pwtest`) + its downloaded chromium

Uses:

```bash
tart clone qa-golden tahoe-base    # restore the working VM after wrecking it
tart clone qa-golden worker-1      # disposable pristine clone per QA run; delete after
tart push / tart pull              # ship it to another mesh Mac via an OCI registry (ghcr.io)
```

`tahoe-base` is the live working VM and drifts (later sessions added real Chrome for Turnstile-gated QA); the golden is the known-good floor. To rebuild golden from nothing: clone the base image, run the provisioning steps in the two references, `tart stop`, `tart clone` to a new golden name.

## SSH auth: key-only. Do NOT drive the guest with sshpass.

`sshpass` looks like the obvious way in (the guest is `admin`/`admin`) and it is
a **trap**: roughly **13% of invocations fail** with `Permission denied` or
`Too many authentication failures`, seemingly at random. It is not load, not
DHCP, not the guest — it's a bug in sshpass 1.10, whose controlling-TTY setup
races ssh's `open("/dev/tty")`. When ssh loses, `read_passphrase()` falls back
to the askpass path, finds no askpass program, and sends an **empty password**.
`ssh -vvv` catches it:

```
debug1: read_passphrase: can't open /dev/tty: Device not configured
debug2: we sent a password packet, wait for reply
debug1: Authentications that can continue: publickey,password,keyboard-interactive
Permission denied (publickey,password,keyboard-interactive).
```

**No ssh option fixes this** — the bug sits upstream of every flag, so retry
loops are the only thing you can do, and they just hide it. Use a key instead.

`scripts/ensure-vm-key.sh <vm-or-ip>` (in this skill) does it idempotently:
generates a **dedicated throwaway key** (`~/.ssh/tart-qa`, `VM_SSH_KEY` to
override) — never the developer's own, never added to their agent — installs
the pubkey in the guest, and verifies key auth. That bootstrap login is the only
place sshpass is allowed. Re-run it after re-cloning an image.

## Generic recipe (any app, any repo)

```bash
tart run tahoe-base --no-graphics &        # boot headless (nohup/disown if scripted)
until nc -z -G 2 "$(tart ip tahoe-base 2>/dev/null)" 22 2>/dev/null; do sleep 5; done
scripts/ensure-vm-key.sh tahoe-base        # idempotent; installs the key on first contact
IP=$(tart ip tahoe-base)                   # DHCP IP, usually 192.168.64.x
ssh $SSH_OPTS admin@$IP '<cmd>'            # no sshpass anywhere
```

with

```bash
SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5
          -o IdentitiesOnly=yes -o IdentityFile='"$HOME"'/.ssh/tart-qa
          -o PreferredAuthentications=publickey -o BatchMode=yes'
```

`IdentitiesOnly=yes` + an explicit `IdentityFile` is load-bearing: without it,
ssh offers every key in the agent (1Password injects several), which eats the
guest's `maxauthtries 6` budget before your key gets a turn. `BatchMode=yes`
fails fast instead of hanging on a password prompt if the key isn't installed.

**Wait on port 22, not on a login.** Guest sshd runs `PerSourcePenalties`
(on by default, OpenSSH 10.2+: `authfail:5 min:15 max:600`) — a boot loop that
hammers failed auths can get the host IP temporarily blocked, and once penalized
no client flag rescues you; you wait it out.

- Deploy an app: `tar czf`, `scp` to guest, `sudo tar xzf -C /Applications`, `open -n /Applications/<App>.app` (lands in the Aqua session).
- Passwordless sudo inside; credentials `admin`/`admin` (needed only for the key bootstrap).
- The guest persists installed tooling **and `~/.ssh/authorized_keys`** across stop/start — provision once, reuse forever.

## Gotchas (each one cost real debugging time)

| Trap | Fix |
|------|-----|
| `tart ip` returns a **stale DHCP lease for a STOPPED VM** | Never use it as a liveness check; parse `tart list` state (State is the last column) |
| Playwright-launched chromium / chrome-for-testing gets **fingerprinted and hard-blocked by bot protection** (Cloudflare Turnstile — Shopify admin, etc.) | Install REAL headed Chrome in the guest and `playwright-cli attach --cdp` to it — full recipe in `references/playwright-cli-in-guest.md` |
| Cold boot: IP arrives long before sshd | Wait up to ~180s for SSH after IP appears — on **port 22** (`nc -z`), not on a login (failed auths feed `PerSourcePenalties`) |
| Intermittent `Permission denied` / `Too many authentication failures` (~13% of calls), fine on retry | **Not transient — it's the sshpass TTY-race bug.** Switch to key auth (`scripts/ensure-vm-key.sh`); see "SSH auth" above. Retry loops only hide it |
| Non-interactive SSH PATH is bare | Absolute paths: `/usr/local/bin/peekaboo`, `/opt/homebrew/bin/npx`, or `export PATH=/opt/homebrew/bin:$PATH` first |
| `scp` of `/opt/homebrew/bin/<tool>` copies a dangling symlink | `readlink -f` first, copy the Cellar binary |
| Stale app instance answers the automation | `pkill -x <App>` before relaunch |
| Only 2 concurrent VMs (Virtualization.framework cap) | Stop one before booting another |
| macOS 15+ host needs an unlocked login.keychain to run any VM | Non-issue on a logged-in dev machine; scripted `security unlock-keychain` on true headless hosts |
| A process runs in the guest but its port/service never appears | A dialog is probably blocking it on the guest desktop — `peekaboo image --mode screen` and LOOK before debugging the app |
| First launch of a brew-cask app blocks on a Gatekeeper "downloaded from the Internet" dialog (despite the image's disabled Gatekeeper) | `sudo xattr -dr com.apple.quarantine "/Applications/<App>.app"` right after install; if already stuck: screenshot, dismiss, `pkill`, relaunch |
| `open -a <Name>` right after a brew install over SSH → "Unable to find application" | LaunchServices hasn't registered it in the Aqua session yet — open **by path**: `open -n "/Applications/<App>.app"` |
| `$` / `$(…)` inside a double-quoted SSH command string expands on the HOST | Single-quote the remote command (or compose it with `quote()` in a justfile); sanity-check with `echo $(hostname)` — it must print the guest's name |
| Guest clock is UTC | Don't expect guest file timestamps to match host local time |

## Deeper references — load on the matching task

- **Driving a native app with peekaboo in the guest** (screenshots, typing, window checks, the `--app` pinning trap): read `references/peekaboo-in-guest.md`.
- **Browser QA with playwright-cli in the guest** (sessions over SSH, browser install, headed mode): read `references/playwright-cli-in-guest.md`.
