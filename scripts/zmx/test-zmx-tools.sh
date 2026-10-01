#!/usr/bin/env bash
# Tests for the zmx tools: label parsing in zmx-ps and the agent -> session
# association in zmx-which (both Nim, scripts/zmx), and zmx-agent-label's
# lifecycle.
#
# Hermetic: the tools pin "$HOME/.local/bin" first on PATH, so a throwaway HOME
# holds the freshly built zmx-ps and zmx-which, wrappers for the Bash sources,
# and stub `zmx`, `claude`, and `ps` that serve fixtures. No live session is
# read or changed.
#
# Usage: scripts/zmx/test-zmx-tools.sh   (or: just test-zmx)

set -uo pipefail
# The Nim tools read the real process table through libproc unless told to use
# `ps`, which is the reader the stub can stand in for. Exported for the whole
# file: agent-sessions runs zmx-which without going through `run`.
export ZMX_PS_SOURCE=ps

here="$(cd "$(dirname "$0")" && pwd)"
src="$(cd "$here/../../dot_local/bin" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/.local/bin"
fix="$tmp/fixtures"
mkdir -p "$bin" "$fix"

# Both Nim tools, side by side when rust-parallel is installed.
if command -v rust-parallel >/dev/null 2>&1; then
  printf '%s\n' zmx-ps:zmx_ps zmx-which:zmx_which |
    rust-parallel -r '(?P<tool>.+):(?P<module>.+)' \
      nim c --hints:off "--nimcache:$tmp/nimcache-{tool}" "-o:$bin/{tool}" "$here/{module}.nim" >&2
else
  for tool in zmx-ps zmx-which; do
    nim c --hints:off --nimcache:"$tmp/nimcache-$tool" -o:"$bin/$tool" "$here/${tool//-/_}.nim" >&2 || break
  done
fi
[[ -x "$bin/zmx-ps" && -x "$bin/zmx-which" ]] || {
  echo "test-zmx-tools: the Nim tools did not build" >&2
  exit 1
}
for tool in zmx-agent-label agent-sessions; do
  printf '#!/bin/sh\nexec /opt/homebrew/bin/bash %s "$@"\n' "$src/executable_$tool" >"$bin/$tool"
done

# zmx stub: `list` prints the fixture; get/set keep labels in a k=v file.
cat >"$bin/zmx" <<'STUB'
#!/opt/homebrew/bin/bash
labels="$FIX/labels"
touch "$labels"
case "$1" in
  list) cat "$FIX/zmx-list" ;;
  get)
    if [[ -n "${3:-}" ]]; then
      v=$(awk -F= -v k="$3" '$1 == k { print substr($0, length(k) + 2); f = 1 } END { exit !f }' "$labels") || exit 1
      printf '%s' "$v"
    else
      sort "$labels" | paste -sd' ' - | tr -d '\n'
    fi
    ;;
  set)
    shift 2
    for kv in "$@"; do
      k=${kv%%=*} v=${kv#*=}
      awk -F= -v k="$k" '$1 != k' "$labels" >"$labels.new"
      mv "$labels.new" "$labels"
      [[ -n "$v" ]] && printf '%s=%s\n' "$k" "$v" >>"$labels"
    done
    ;;
esac
exit 0
STUB

cat >"$bin/claude" <<'STUB'
#!/bin/sh
cat "$FIX/agents.json"
STUB

# ps stub: `-axo ...` is the process table, `eww -p PID` one process's env.
cat >"$bin/ps" <<'STUB'
#!/opt/homebrew/bin/bash
if [[ "$1" == eww ]]; then
  echo "  PID   TT  STAT      TIME COMMAND"
  awk -v p="$3" '$1 == p' "$FIX/ps-env"
else
  cat "$FIX/ps-table"
fi
STUB
chmod +x "$bin"/*

# alpha: labelled, plus a foreign label. beta: run-created, no labels.
# gamma: stale agent label from a crashed session. delta: no optional fields.
printf '%s\n' \
  $'→ name=alpha\tpid=100\tclients=1\tcreated=1000\tcwd=file://host/Users/x/proj%20a/\tagent=claude\tclaude_pid=111\tclaude_session=sid-a\trole=reviewer' \
  $'  name=beta\tpid=200\tclients=0\tcreated=1000\tcwd=file://host/tmp\tended=5\texit_code=0' \
  $'  name=gamma\tpid=300\tclients=1\tcreated=1000\tcwd=/plain\tcmd=sleep 5\tagent=claude\tclaude_session=sid-stale' \
  $'  name=delta\tpid=400\tclients=2\tcreated=1000' \
  $'  name=dead\terr=ConnectionRefused\tstatus=unreachable' >"$fix/zmx-list"

printf '%s\n' \
  '101 100 01:00 100 -zsh' \
  '111 101 01:00 100 claude' \
  '201 200 01:00 100 -bash' \
  '301 300 01:00 100 -zsh' \
  '311 301 01:00 100 claude' \
  '401 400 01:00 100 -zsh' \
  '411 401 01:00 100 claude' \
  '999 1 01:00 100 claude' >"$fix/ps-table"

# 111's env names the wrong session on purpose: the label has to win.
printf '%s\n' \
  '111 s000 S 0:00 claude ZMX_SESSION=beta TERM=x' \
  '311 s001 S 0:00 claude ZMX_SESSION=gamma TERM=x' \
  '411 s002 S 0:00 claude TERM=x' \
  '999 s003 S 0:00 claude TERM=x' >"$fix/ps-env"

cat >"$fix/agents.json" <<'JSON'
[
  {"pid": 111, "kind": "interactive", "sessionId": "sid-a", "status": "busy", "cwd": "/a"},
  {"pid": 311, "kind": "interactive", "sessionId": "sid-b", "status": "idle", "cwd": "/b"},
  {"pid": 411, "kind": "interactive", "sessionId": "sid-c", "status": "waiting", "cwd": "/c"},
  {"pid": 999, "kind": "interactive", "sessionId": "sid-d", "status": "idle", "cwd": "/d"},
  {"id": "bg", "kind": "background", "sessionId": "sid-bg", "state": "blocked", "cwd": "/e"}
]
JSON

pass=0 fail=0
check() { # name actual expected
  if [[ "$2" == "$3" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$3" "$2" >&2
  fi
}
run() { HOME="$tmp" FIX="$fix" "$@"; }

# --- zmx-ps: labels ---------------------------------------------------------
ps_json=$(run "$bin/zmx-ps")
check "ps: unreachable session skipped" "$(jaq -r 'map(.name) | join(",")' <<<"$ps_json")" "alpha,beta,gamma,delta"
check "ps: labels object" "$(jaq -c '.[0].labels' <<<"$ps_json")" \
  '{"agent":"claude","claude_pid":"111","claude_session":"sid-a","role":"reviewer"}'
check "ps: ended/exit_code are not labels" "$(jaq -c '.[1].labels' <<<"$ps_json")" '{}'
check "ps: cmd is not a label" "$(jaq -c '.[2].labels' <<<"$ps_json")" '{"agent":"claude","claude_session":"sid-stale"}'
check "ps: no optional fields" "$(jaq -c '.[3] | [.labels, .cwd]' <<<"$ps_json")" '[{},""]'
check "ps: cwd decoded" "$(jaq -r '.[0].cwd' <<<"$ps_json")" "/Users/x/proj a"
check "ps: occupancy unchanged" "$(jaq -r 'map(.state) | join(",")' <<<"$ps_json")" "active,idle,active,active"
check "ps: --label key" "$(run "$bin/zmx-ps" --label agent --names | paste -sd, -)" "alpha,gamma"
check "ps: --label key=value" "$(run "$bin/zmx-ps" --label role=reviewer --names)" "alpha"
check "ps: --label no match" "$(run "$bin/zmx-ps" --label role=other | jaq length)" "0"

# --- zmx-which: association precedence --------------------------------------
which_json=$(run "$bin/zmx-which" --json)
assoc() { jaq -r --argjson p "$1" '.[] | select(.pid == $p) | "\(.zmx_session)/\(.association_source)"' <<<"$which_json"; }
check "which: label beats process env" "$(assoc 111)" "alpha/label"
check "which: process env fallback, stale label ignored" "$(assoc 311)" "gamma/process_env"
check "which: process tree fallback" "$(assoc 411)" "delta/process_tree"
check "which: unresolved" "$(assoc 999)" "null/null"
check "which: pid-less agents omitted" "$(jaq length <<<"$which_json")" "4"
check "which: occupancy and clients ride along" \
  "$(jaq -c '.[] | select(.pid == 411) | [.occ, .clients, .status, .session_id]' <<<"$which_json")" \
  '["active",2,"waiting","sid-c"]'
check "which: filter by session" "$(run "$bin/zmx-which" --json alpha | jaq -r 'map(.pid) | join(",")')" "111"
check "which: filter by pid" "$(run "$bin/zmx-which" --json 311 | jaq -r 'map(.zmx_session) | join(",")')" "gamma"

# --- agent-sessions: contract ------------------------------------------------
as_json=$(HOME="$tmp" FIX="$fix" "$bin/agent-sessions" --json --within 0)
check "agent-sessions: association carried" \
  "$(jaq -c '[.[] | select(.source == "claude") | [.pid, .zmx_session, .association_source, .occ]]' <<<"$as_json")" \
  '[[111,"alpha","label","active"],[311,"gamma","process_env","active"],[411,"delta","process_tree","active"],[999,null,null,null],[null,null,null,null]]'

# --- zmx-agent-label: lifecycle ---------------------------------------------
lbl() { printf '{"session_id":"%s"}' "$2" | HOME="$tmp" FIX="$fix" ZMX_SESSION=alpha CLAUDE_PID="${3:-$$}" "$bin/zmx-agent-label" "$1" claude 2>/dev/null; }
labels() { run "$bin/zmx" get .; }

lbl set s1
check "label: set" "$(labels)" "agent=claude claude_pid=$$ claude_session=s1"
lbl set s2
check "label: /clear replaces the id" "$(labels)" "agent=claude claude_pid=$$ claude_session=s2"
lbl unset s1
check "label: late SessionEnd for the old id is a no-op" "$(labels)" "agent=claude claude_pid=$$ claude_session=s2"
lbl set nested $PPID
check "label: nested agent can't take a live owner's session" "$(labels)" "agent=claude claude_pid=$$ claude_session=s2"
run "$bin/zmx" set . role=reviewer
lbl unset s2
check "label: exit removes only the agent's keys" "$(labels)" "role=reviewer"
run "$bin/zmx" set . agent=claude claude_session=crashed claude_pid=999999
lbl set s3
check "label: a dead owner's labels are replaced" "$(labels)" "agent=claude claude_pid=$$ claude_session=s3 role=reviewer"
printf '{}' | HOME="$tmp" FIX="$fix" ZMX_SESSION=alpha "$bin/zmx-agent-label" unset claude 2>/dev/null
check "label: no session_id leaves labels alone" "$(labels)" "agent=claude claude_pid=$$ claude_session=s3 role=reviewer"
: >"$fix/labels"
printf '{"session_id":"s4"}' | HOME="$tmp" FIX="$fix" env -u ZMX_SESSION "$bin/zmx-agent-label" set claude
check "label: outside zmx does nothing" "$(labels)" ""
HOME="$tmp" FIX="$fix" ZMX_SESSION=alpha "$bin/zmx-agent-label" bogus claude </dev/null 2>/dev/null
check "label: usage error exits 2" "$?" "2"

printf '%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
