#!/usr/bin/env bash
# ensure-vm-key.sh <vm-name-or-ip>
#
# Makes key-only SSH to a tart guest work, idempotently:
#   1. generates a DEDICATED keypair (never the developer's own) if missing,
#   2. installs its pubkey into the guest's authorized_keys — the one place that
#      still needs password auth, and therefore the one place sshpass survives,
#   3. verifies key auth works before returning.
#
# Then drive the guest with key-only options (no sshpass anywhere):
#
#   VM_SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
#                -o ConnectTimeout=5 -o IdentitiesOnly=yes
#                -o IdentityFile="$HOME/.ssh/tart-qa"
#                -o PreferredAuthentications=publickey -o BatchMode=yes)
#   ssh "${VM_SSH_OPTS[@]}" admin@"$(tart ip <vm>)" '<cmd>'
#
# WHY (do not "fix" this by retrying sshpass): sshpass 1.10's controlling-TTY
# setup races ssh's open("/dev/tty"). When ssh loses, read_passphrase() falls
# back to the askpass path, finds no askpass program, and sends an EMPTY
# password. `ssh -vvv` catches it red-handed:
#
#     debug1: read_passphrase: can't open /dev/tty: Device not configured
#     debug2: we sent a password packet, wait for reply
#     debug1: Authentications that can continue: publickey,password,...
#     Permission denied (publickey,password,keyboard-interactive).
#
# ~13% of invocations. NO ssh option fixes it — the bug is upstream of every
# flag. Loaded ssh-agent keys are only an amplifier: they eat the guest's
# `maxauthtries 6` budget, turning the same failure into "Too many
# authentication failures" — which is why the options above pin IdentitiesOnly
# + an explicit IdentityFile.
#
# The key is passphrase-less on purpose: it grants access to a local, throwaway
# guest whose password is the published default (admin/admin). It is strictly
# less exposed than passing that password on every command line, where `ps`
# shows it.
#
# Env overrides: VM_SSH_KEY, VM_USER, VM_PASS.
set -euo pipefail

target="${1:?usage: ensure-vm-key.sh <vm-name-or-ip>}"
key="${VM_SSH_KEY:-$HOME/.ssh/tart-qa}"
user="${VM_USER:-admin}"
pass="${VM_PASS:-admin}"

# Accept a VM name or a literal IP.
if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ip="$target"
else
  ip="$(tart ip "$target" 2>/dev/null || true)"
  [[ -n "$ip" ]] || { echo "could not resolve an IP for VM '$target' (is it running?)" >&2; exit 1; }
fi

base_opts=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=5
  -o LogLevel=ERROR
)
key_opts=("${base_opts[@]}" -o IdentitiesOnly=yes -o IdentityFile="$key"
  -o PreferredAuthentications=publickey -o BatchMode=yes)

key_auth_works() {
  ssh "${key_opts[@]}" "$user@$ip" 'echo ok' 2>/dev/null | grep -q ok
}

if [[ ! -f "$key" ]]; then
  mkdir -p "$(dirname "$key")"
  chmod 700 "$(dirname "$key")"
  ssh-keygen -t ed25519 -N '' -C "tart-qa" -f "$key" >/dev/null
  echo "generated dedicated QA key: $key"
fi

key_auth_works && exit 0

command -v sshpass >/dev/null || {
  echo "sshpass not installed (needed once, to install the key): brew install sshpass" >&2
  exit 1
}

echo "installing QA pubkey into $user@$ip …"
pub="$(cat "$key.pub")"
# Password auth ONLY here, and retried — this is the sshpass-flake window.
for attempt in 1 2 3 4 5 6; do
  if sshpass -p "$pass" ssh "${base_opts[@]}" \
    -o PubkeyAuthentication=no -o PreferredAuthentications=password \
    -o NumberOfPasswordPrompts=1 "$user@$ip" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qxF '$pub' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys" 2>/dev/null
  then
    break
  fi
  [[ $attempt -eq 6 ]] && { echo "could not install the key after 6 attempts" >&2; exit 1; }
  sleep 4
done

key_auth_works || { echo "key installed but key auth still fails — check the guest's sshd" >&2; exit 1; }
echo "key auth ready for $user@$ip"
