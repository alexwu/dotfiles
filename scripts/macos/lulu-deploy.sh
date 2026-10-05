#!/usr/bin/env bash
set -euo pipefail

prog=lulu-deploy
host=${LULU_DEPLOY_HOST:-build@bombeemac-mini}
rsync_path=${LULU_DEPLOY_RSYNC_PATH:-}
dry_run=0
sandbox=0
remote_root=Library/Caches/lulu/deploy/workspaces
# A build script on the far side must never be able to borrow local keys.
ssh_opts=(-o ForwardAgent=no -o ClearAllForwardings=yes)

usage() {
  cat <<EOF
Sync the current git repository to a build host and run a command there.

Usage: $prog [OPTIONS] [--] COMMAND [ARG...]

Arguments:
  COMMAND [ARG...]  Command to run in the synced workspace on the host

Options:
      --host [USER@]HOST  SSH destination (env: LULU_DEPLOY_HOST,
                          default: build@bombeemac-mini)
      --rsync-path PATH   rsync binary to use on the host
                          (env: LULU_DEPLOY_RSYNC_PATH, default: Homebrew's
                          if present, else the one on the host's PATH)
      --sandbox           Run COMMAND with no network, a minimal environment,
                          and file access limited to the workspace, the Rust
                          toolchain and Xcode (through mise on the host)
  -n, --dry-run           Create the workspace directory, list what the sync
                          would change, then stop
  -h, --help              Print help

Options go before COMMAND; everything after it belongs to COMMAND.
The working tree is synced, minus .git and anything .gitignore excludes,
to ~/$remote_root/<repo>-<path hash> on the host.

Exit status is COMMAND's own. 125 means the sync failed before COMMAND
ran, and 2 is a usage error. Progress lines go to stderr, styled when it
is a terminal; set NO_COLOR to keep them plain.

Examples:
  $prog -- cargo build --release
  $prog --host build@bombeemac-mini -- just test
  $prog -- cargo fetch && $prog --sandbox -- cargo build --offline
EOF
}

# Styling is for a person at a terminal; pipes and logs get plain lines.
if [[ -t 2 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  pretty=1
  bold=$'\e[1m' dim=$'\e[2m' cyan=$'\e[36m' green=$'\e[32m' red=$'\e[31m' reset=$'\e[0m'
  glyph_step=$'▸' glyph_ok=$'✔' glyph_fail=$'✘' glyph_to=$'→'
else
  pretty=0
  bold='' dim='' cyan='' green='' red='' reset=''
  glyph_step='' glyph_ok='' glyph_fail='' glyph_to='->'
fi

note() { echo "$prog: $*" >&2; }

error_note() { echo "$red$prog:$reset $*" >&2; }

step() {
  if ((pretty)); then
    printf '%s%s %-4s%s %s\n' "$cyan$bold" "$glyph_step" "$1" "$reset" "$2" >&2
  else
    note "$1 $2"
  fi
}

now_ms() {
  local t=${EPOCHREALTIME:-$SECONDS.000000}
  t=${t/[.,]/}
  echo $((10#${t%???}))
}

elapsed_since() {
  local ms=$(($(now_ms) - $1))
  printf '%d.%ds' $((ms / 1000)) $(((ms % 1000) / 100))
}

usage_error() {
  error_note "$*"
  note "try '$prog --help'"
  exit 2
}

setup_error() {
  error_note "$*"
  exit 125
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -n | --dry-run) dry_run=1 ;;
    --sandbox) sandbox=1 ;;
    --host)
      (($# >= 2)) || usage_error "--host needs a destination"
      host=$2
      shift
      ;;
    --host=*) host=${1#*=} ;;
    --rsync-path)
      (($# >= 2)) || usage_error "--rsync-path needs a path"
      rsync_path=$2
      shift
      ;;
    --rsync-path=*) rsync_path=${1#*=} ;;
    --)
      shift
      break
      ;;
    -*) usage_error "unknown option '$1'" ;;
    *) break ;;
  esac
  shift
done

((dry_run || $# > 0)) || usage_error "expected a COMMAND to run on the host"

# A leading '-' here would be read by ssh as one of its own options.
[[ $host =~ ^([A-Za-z0-9][A-Za-z0-9._-]*@)?[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
  usage_error "invalid host '$host'"
[[ -z $rsync_path || $rsync_path =~ ^/[A-Za-z0-9._/-]+$ ]] ||
  usage_error "--rsync-path must be a plain absolute path, got '$rsync_path'"

local_root=$(git rev-parse --show-toplevel 2>/dev/null) ||
  usage_error "not inside a git repository"
project=$(basename "$local_root")
[[ $project =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
  usage_error "repository name '$project' can't be used as a remote path"

# Same-named repositories and worktrees each get their own workspace.
path_hash=$(printf '%s' "$local_root" | shasum -a 256)
remote_dir=$remote_root/$project-${path_hash:0:8}

rsync_args=(
  --archive
  --compress
  --delete-delay
  --max-delete=10000
  --rsh="ssh ${ssh_opts[*]}"
  --exclude=/.git
  --exclude=.DS_Store
  --filter=':- .gitignore'
)
if ((dry_run)); then
  rsync_args+=(--dry-run --itemize-changes)
fi

# WARNING: Apple's openrsync ignores the .gitignore filter when it deletes, so
# as the receiver it wipes ignored build output (target/) on every sync.
if [[ -n $rsync_path ]]; then
  candidates="'$rsync_path'"
else
  # shellcheck disable=SC2016 # the substitution runs on the host, not here
  candidates='/opt/homebrew/bin/rsync /usr/local/bin/rsync "$(command -v rsync)"'
fi

cd "$local_root"

step sync "$bold$project$reset $dim$glyph_to$reset $host$dim:$remote_dir$reset"
sync_start=$(now_ms)
status=0
# shellcheck disable=SC2029 # remote_dir and candidates are validated above and expand here on purpose
remote_rsync=$(ssh "${ssh_opts[@]}" "$host" "
  mkdir -p \"\$HOME/$remote_dir\" || exit 1
  for r in $candidates; do
    [ -x \"\$r\" ] || continue
    if \"\$r\" --version 2>&1 | grep -q openrsync; then exit 3; fi
    echo \"\$r\"
    exit 0
  done
  exit 4
") || status=$?
case $status in
  0) ;;
  3) setup_error "the rsync on $host is Apple's openrsync, which deletes ignored build output on sync; install rsync there or pass --rsync-path" ;;
  4) setup_error "no rsync found on $host${rsync_path:+ at $rsync_path}" ;;
  *) setup_error "couldn't create the workspace on $host" ;;
esac
rsync_args+=(--rsync-path="$remote_rsync")

rsync "${rsync_args[@]}" ./ "$host:$remote_dir/" ||
  setup_error "sync to $host failed"
sync_time=$(elapsed_since "$sync_start")

if ((dry_run)); then
  note "dry run: the workspace directory exists, no files were synced and COMMAND was not run"
  exit 0
fi

remote=(ssh "${ssh_opts[@]}")
# A terminal lets Ctrl-C reach the remote command; without one, stdout and
# stderr stay separate for pipes.
if [[ -t 0 && -t 1 ]]; then
  # LogLevel=error drops ssh's own "Connection to ... closed." line.
  remote+=(-t -o LogLevel=error)
fi

quoted_command=$(printf '%q ' "$@")
# shellcheck disable=SC2016 # everything in single quotes expands on the host
if ((sandbox)); then
  # NOTE: mise runs from /tmp so it never evaluates the synced repository's
  # own mise config, and the allow paths are absolute because mise 2026.9.15
  # grants nothing for a relative one.
  remote_command='ws="$HOME/'"$remote_dir"'" && dev=$(xcode-select -p) && cd /tmp && exec mise exec --deny-all'
  remote_command+=' --allow-read="$ws" --allow-read="$HOME/.rustup" --allow-read="$HOME/.cargo"'
  remote_command+=' --allow-read=/private/var/select --allow-read="${dev%/Contents/Developer}"'
  remote_command+=' --allow-write="$ws" --allow-write="$(getconf DARWIN_USER_TEMP_DIR)"'
  remote_command+=' --allow-write="$(getconf DARWIN_USER_CACHE_DIR)"'
  remote_command+=' -- sh -c '\''cd "$1" && shift && exec "$@"'\'' sh "$ws" '"$quoted_command"
  step run "$bold$*$reset $dim(sandboxed)$reset"
else
  remote_command='cd "$HOME/'"$remote_dir"'" && exec '"$quoted_command"
  step run "$bold$*$reset"
fi

run_start=$(now_ms)
status=0
"${remote[@]}" "$host" "$remote_command" || status=$?
run_time=$(elapsed_since "$run_start")

if ((status == 0)); then
  summary="done in $run_time $dim(sync $sync_time)$reset"
  if ((pretty)); then
    echo "$green$bold$glyph_ok$reset $summary" >&2
  else
    note "$summary"
  fi
else
  summary="exit $status after $run_time $dim(sync $sync_time)$reset"
  if ((pretty)); then
    echo "$red$bold$glyph_fail$reset $summary" >&2
  else
    note "$summary"
  fi
fi
exit "$status"
