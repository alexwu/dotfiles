---
name: tart-vm-qa
description: Run GUI QA inside a headless tart macOS VM so the app under test never steals focus on the host. Use when asked to QA, smoke-test, screenshot, or drive a macOS app (btty or any .app) or a browser flow "in the VM", "headless", "without stealing focus", "in the background", or via tart. Covers boot/deploy/drive over SSH, peekaboo GUI automation in the guest, and playwright-cli browser QA in the guest.
---

# Headless VM QA with tart

A tart macOS guest (`tahoe-base`, cloned from `ghcr.io/cirruslabs/macos-tahoe-base`) runs with **no host window** under `tart run --no-graphics`, yet still renders a full virtual display with an auto-logged-in Aqua session. Everything runs over SSH; the host keeps focus the entire time. Proven end-to-end 2026-07-09 (Btty + peekaboo + headed Chromium; same day: real Chrome + an authenticated, Turnstile-gated admin — see the playwright reference).

**Why permissions just work:** the Cirrus images pre-grant Accessibility, ScreenCapture, PostEvent, and AppleEvents to `/usr/libexec/sshd-keygen-wrapper` in TCC.db (SIP and Gatekeeper are disabled in the image). Any binary invoked over SSH inherits those grants — peekaboo, playwright, anything. No dialogs, no tccutil, no MDM.

## btty QA (lulu-code) — use the mise tasks

```bash
mise run qa:vm          # full cycle: package → boot → deploy → peekaboo smoke → screenshot to dist/qa/
mise run qa:vm:up       # boot headless + ensure peekaboo in guest
mise run qa:vm:deploy   # ship dist/Btty.app into guest, clean-relaunch
mise run qa:vm:smoke    # type a command into Btty, verify it executed, screenshot
mise run qa:vm:shot     # screenshot guest screen to dist/qa/
mise run qa:vm:down     # stop the VM
packaging/qa-vm.sh ssh  # interactive shell into the guest
```

The implementation is `packaging/qa-vm.sh` — read it before extending; every helper encodes a gotcha from the table below.

## Generic recipe (any app, any repo)

```bash
tart run tahoe-base --no-graphics &   # boot headless (nohup/disown if scripted)
IP=$(tart ip tahoe-base)              # DHCP IP, usually 192.168.64.x
sshpass -p admin ssh $SSH_OPTS admin@$IP '<cmd>'
```

with

```bash
SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5
          -o PreferredAuthentications=password -o IdentitiesOnly=yes'
```

- Deploy an app: `tar czf`, `scp` to guest, `sudo tar xzf -C /Applications`, `open -a <App>` (lands in the Aqua session).
- Passwordless sudo inside; credentials `admin`/`admin`.
- The guest persists installed tooling across stop/start — provision once, reuse forever.

## Gotchas (each one cost real debugging time)

| Trap | Fix |
|------|-----|
| `tart ip` returns a **stale DHCP lease for a STOPPED VM** | Never use it as a liveness check; parse `tart list` state (see `vm_running()` in qa-vm.sh) |
| Cold boot: IP arrives long before sshd | Wait up to ~180s for SSH after IP appears |
| ssh-agent offers every key → "Too many authentication failures" | `PreferredAuthentications=password -o IdentitiesOnly=yes` |
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
- Full recorded recipe + provenance: `bd recall tart-headless-qa-recipe-2026-07` (lulu-code repo).
