#!/usr/bin/env bash
set -euo pipefail

prog=ensure-build-user
user=build
dry_run=0
prompt_password=0

usage() {
  cat <<EOF
Create or converge an unprivileged, SSH-key-only macOS build account.

Usage: $prog [OPTIONS] PUBKEY_FILE

Arguments:
  PUBKEY_FILE  OpenSSH public key allowed to log in ('-' reads stdin)

Options:
      --user NAME        Account short name (default: build)
      --prompt-password  Ask for the new account's password instead of
                         setting a random one nobody keeps
  -n, --dry-run          Print the privileged commands instead of running them
  -h, --help             Print help

Run it on the build host as an admin user; it calls sudo itself. Safe to
repeat: an existing account is kept, and its authorized_keys is replaced
with exactly the given key.
EOF
}

note() { echo "$prog: $*" >&2; }

fail() {
  note "$*"
  exit 1
}

usage_error() {
  note "$*"
  note "try '$prog --help'"
  exit 2
}

run() {
  if ((dry_run)); then
    {
      printf 'would run:'
      printf ' %q' "$@"
      printf '\n'
    } >&2
  else
    "$@"
  fi
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -n | --dry-run) dry_run=1 ;;
    --prompt-password) prompt_password=1 ;;
    --user)
      (($# >= 2)) || usage_error "--user needs a name"
      user=$2
      shift
      ;;
    --user=*) user=${1#*=} ;;
    --)
      shift
      break
      ;;
    - | [!-]*) break ;;
    *) usage_error "unknown option '$1'" ;;
  esac
  shift
done

(($# == 1)) || usage_error "expected exactly one PUBKEY_FILE"
key_file=$1

[[ $(uname -s) == Darwin ]] || usage_error "this only works on macOS"
((EUID != 0)) || usage_error "run as an admin user, not root; it calls sudo itself"
[[ $user =~ ^[a-z][a-z0-9_-]{0,30}$ ]] || usage_error "invalid account name '$user'"
if ((prompt_password && ! dry_run)) && [[ $key_file == - || ! -t 0 ]]; then
  usage_error "--prompt-password needs a terminal on stdin; pass the key as a file and use 'ssh -t'"
fi

if [[ $key_file == - ]]; then
  key=$(cat)
else
  [[ -r $key_file ]] || usage_error "can't read '$key_file'"
  key=$(<"$key_file")
fi

# A line must start with the key type, so an authorized_keys options prefix
# (command=, permitopen=, ...) can't ride in with the key.
key_pattern='^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) [A-Za-z0-9+/]+=*( [^[:cntrl:]]*)?$'
[[ $key != *$'\n'* && $key =~ $key_pattern ]] ||
  usage_error "'$key_file' isn't a single OpenSSH public key line"
fingerprint=$(ssh-keygen -l -f /dev/stdin <<<"$key") ||
  usage_error "ssh-keygen rejected the key in '$key_file'"

record="/Users/$user"
user_exists() { dscl . -read "$record" >/dev/null 2>&1; }

((dry_run)) || sudo -v

if user_exists; then
  note "account '$user' already exists, keeping it"
  if ((prompt_password)); then
    note "password left alone; change it with 'sudo sysadminctl -resetPasswordFor $user -newPassword -'"
  fi
else
  note "creating account '$user'"
  if ((prompt_password)); then
    # sysadminctl reads the password from the terminal when given '-'.
    password=-
  elif ((dry_run)); then
    password='<random>'
  else
    # NOTE: nobody keeps this password, so the key is the only way in. It is
    # visible in the process list for the length of this one call.
    password=$(openssl rand -base64 32)
  fi
  run sudo sysadminctl -addUser "$user" -fullName "Build User" \
    -shell /bin/zsh -password "$password"
  unset password
  # sysadminctl can report success without creating anything.
  ((dry_run)) || user_exists || fail "sysadminctl did not create '$user'"
fi

if dseditgroup -o checkmember -m "$user" admin >/dev/null 2>&1; then
  fail "'$user' is in the admin group; remove it with 'sudo dseditgroup -o edit -d $user -t user admin'"
fi

run sudo dscl . -create "$record" IsHidden 1

# Remote Login set to "only these users" keeps its allow list in this group.
if dscl . -read /Groups/com.apple.access_ssh >/dev/null 2>&1; then
  run sudo dseditgroup -o edit -a "$user" -t user com.apple.access_ssh
fi

home=/Users/$user
if home_line=$(dscl . -read "$record" NFSHomeDirectory 2>/dev/null); then
  home=${home_line#NFSHomeDirectory: }
fi
[[ -d $home ]] || run sudo createhomedir -c -u "$user"

run sudo chmod 700 "$home"
run sudo -u "$user" mkdir -p -m 700 "$home/.ssh"
if ((dry_run)); then
  note "would write $home/.ssh/authorized_keys"
else
  printf 'restrict,pty %s\n' "$key" |
    sudo -u "$user" tee "$home/.ssh/authorized_keys" >/dev/null
fi
run sudo -u "$user" chmod 600 "$home/.ssh/authorized_keys"

note "account '$user' accepts only: $fingerprint"

# New accounts join 'staff', so group access counts as much as other.
mode=$(stat -f '%Lp' "$HOME")
if (((8#$mode & 8#055) != 0)); then
  note "warning: $HOME is mode $mode, so '$user' can read it; 'chmod go-rx $HOME' closes that"
fi
