# Caddy (caddy-tailscale)

A custom Caddy build fronts local services as their own tailnet nodes via the
[`caddy-tailscale`](https://github.com/tailscale/caddy-tailscale) plugin. First
use: llama-swap at `https://llama-swap.burro-neon.ts.net` (its own node, so the
`/ui/` UI and `/v1/` API both work at root — no path-prefix rewriting).

## Why a custom binary
Caddy plugins compile *into* the binary (Go, no runtime plugin dir), so adding
one means rebuilding Caddy. The Homebrew `caddy` does NOT have the plugin — a
`brew upgrade caddy` won't touch this binary, and updating Caddy means rebuilding.

- Binary: `~/.local/bin/caddy-tailscale` (~61 MB, NOT chezmoi-managed — too big).
- Rebuild (needs Go, present via mise):
  ```sh
  go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest   # once; lands in $(go env GOBIN)
  xcaddy build --with github.com/tailscale/caddy-tailscale --output ~/.local/bin/caddy-tailscale
  ```
- Verify the plugin is baked in: `caddy-tailscale list-modules | rg tailscale`
  → `tls.get_certificate.tailscale`, `http.authentication.providers.tailscale`,
  `http.reverse_proxy.transport.tailscale`, `tailscale`.
- **Updating versions** — everything is compiled in, so every bump is a rebuild + restart.
  The front door is `J caddy-rebuild [TS]` (global justfile, group `caddy`): latest plugin +
  `tailscale.com@TS` (default `latest`), prints the baked-in deps (`J caddy-deps` alone does
  just that), then kickstarts the agent. Manually, the knobs are:
  - Plugin (and the tsnet/tailscale.com version its go.mod pins): re-run the `xcaddy build`
    above — `--with <module>` with no `@version` pulls latest master.
  - Force a newer tailscale.com than the plugin pins: add a second
    `--with tailscale.com@v1.XX.X` (extra `--with` pins the transitive dep).
  - Caddy core: xcaddy builds the latest release by default; pin with
    `xcaddy build v2.11.4 --with …`.
  - Check what a binary embeds: `caddy-tailscale build-info | rg 'tailscale.com|caddy-tailscale'`
    and `caddy-tailscale version`.
  - Then `launchctl kickstart -k gui/$(id -u)/dev.mise.caddy-tailscale` to run the new build.

## Config + service
- Caddyfile: `dot_config/caddy/Caddyfile` → `~/.config/caddy/Caddyfile`. Site address
  is the FULL `*.ts.net` hostname + `bind tailscale/<node>`; auto_https then pulls the
  cert from Tailscale automatically (no `tls` block needed with the full hostname).
- LaunchAgent is mise-managed: `[bootstrap.macos.launchd.agents.caddy-tailscale]` in
  `mise-config.toml`, label `dev.mise.caddy-tailscale`. Mirrors the llama-swap agent:
  `fnox exec -c ~/.config/fnox/config.toml -- caddy-tailscale run …`,
  `run_at_load` + `keep_alive`, logs to `~/.config/caddy/caddy-tailscale.log`.
- tsnet runs in userspace, so no privileged bind — a user LaunchAgent is enough.
- Node state: `~/.local/state/caddy-tailscale/` (per-node subdir). Survives restarts.

## TS_AUTHKEY + the tag (required for registration)
- `tailscale.auth_key` reads `{env.TS_AUTHKEY}` (fnox-injected). The key already exists in
  fnox — it's the SAME OAuth client secret the mini's ScaleTail containers register with.
- Because it's an OAuth client secret, Tailscale REQUIRES a tag on the node. Without one,
  startup dies with `oauth authkeys require --advertise-tags` and KeepAlive crash-loops.
  The Caddyfile sets `tags tag:container` — matching the containers' `TS_EXTRA_ARGS=--advertise-tags=tag:container`.
- The node registers as a **tagged-device** (owned by the tag, not your user).
- Only consulted to (re)register; after first auth, `state_dir` carries it. To rotate:
  `fnox -c ~/.config/fnox/config.toml set TS_AUTHKEY <key>`.

## Gotchas
- Agent-def changes go live via `mise bootstrap macos launchd-agents apply --yes` (same as
  llama-swap) — `mise-config.toml` is a symlink target, so no `chezmoi apply` involved at all.
- LaunchAgent CWD is `/` (SIP read-only) — every path in the Caddyfile/plist is absolute.
- The laptop sleeps: `llama-swap.burro-neon.ts.net` only resolves while `bombeebook`
  is awake. Physics, not a config bug.
- Coexists with `tailscale serve` on `bombeebook` (a separate node). The serve mount
  (`https://bombeebook.burro-neon.ts.net/` → `:8000`) still works independently; drop it
  with `tailscale serve reset` if the caddy node fully replaces it.

## Load / reload / status
```sh
mise bootstrap macos launchd-agents apply --yes            # (re)write plist + reload + kickstart
launchctl kickstart -k gui/$(id -u)/dev.mise.caddy-tailscale   # plain restart, no config change
tailscale status | rg llama-swap          # node registered?
curl -s https://llama-swap.burro-neon.ts.net/v1/models   # serving?
```
