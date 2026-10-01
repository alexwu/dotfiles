#!/usr/bin/env bash
# Tests for the zmx tools (all Nim, scripts/zmx): label parsing in zmx-ps, the
# agent -> session association in zmx-which, the agent-sessions contract, the
# mission-control view, zmx-reap's verdicts, zmx-env, the rows zmx-select
# hands to fzf, and zmx-agent-label's lifecycle.
#
# Hermetic: the tools pin "$HOME/.local/bin" first on PATH, so a throwaway HOME
# holds the eight freshly built tools and stub `zmx`, `claude`, `ps`, and
# `wezterm` that serve fixtures. No live session is read, changed or killed.
#
# Usage: scripts/zmx/test-zmx-tools.sh   (or: just test-zmx)

set -uo pipefail
# The Nim tools read the real process table through libproc unless told to use
# `ps`, which is the reader the stub can stand in for.
export ZMX_PS_SOURCE=ps

here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/.local/bin"
fix="$tmp/fixtures"
mkdir -p "$bin" "$fix"

# The Nim tools, side by side when rust-parallel is installed.
nim_tools=(zmx-ps zmx-which agent-sessions mission-control zmx-reap zmx-env zmx-select zmx-agent-label)
if command -v rust-parallel >/dev/null 2>&1; then
  for tool in "${nim_tools[@]}"; do printf '%s:%s\n' "$tool" "${tool//-/_}"; done |
    rust-parallel -r '(?P<tool>.+):(?P<module>.+)' \
      nim c --hints:off "--nimcache:$tmp/nimcache-{tool}" "-o:$bin/{tool}" "$here/{module}.nim" >&2
else
  for tool in "${nim_tools[@]}"; do
    nim c --hints:off --nimcache:"$tmp/nimcache-$tool" -o:"$bin/$tool" "$here/${tool//-/_}.nim" >&2 || break
  done
fi
for tool in "${nim_tools[@]}"; do
  [[ -x "$bin/$tool" ]] || {
    echo "test-zmx-tools: $tool did not build" >&2
    exit 1
  }
done

# zmx stub: `list` prints the fixture; get/set keep labels in a k=v file; `kill`
# records the names it was given.
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
  kill)
    shift
    printf '%s\n' "$@" >>"$FIX/killed"
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

# wezterm stub: one pane, so mission-control never reaches the real one.
cat >"$bin/wezterm" <<'STUB'
#!/bin/sh
printf '[{"cwd": "file://host/Users/x/proj%%20a/", "workspace": "main"}]\n'
STUB
chmod +x "$bin"/*

# One Codex rollout. Its mtime is now, so any positive --within includes it.
mkdir -p "$tmp/.codex/sessions/2026/01/01"
printf '%s\n' \
  '{"type":"session_meta","payload":{"id":"0199aaaa-bbbb-cccc","cwd":"/work/app","git":{"branch":"feat/y"}}}' \
  '{"type":"other"}' >"$tmp/.codex/sessions/2026/01/01/rollout-test.jsonl"

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
  {"pid": 111, "kind": "interactive", "sessionId": "sid-a", "status": "busy", "cwd": "/a", "name": "alpha-work"},
  {"pid": 311, "kind": "interactive", "sessionId": "sid-b", "status": "idle", "cwd": "/b"},
  {"pid": 411, "kind": "interactive", "sessionId": "sid-c", "status": "waiting", "cwd": "/c"},
  {"pid": 999, "kind": "interactive", "sessionId": "sid-d", "status": "idle", "cwd": "/d"},
  {"id": "bg", "kind": "background", "sessionId": "sid-bg", "status": "idle", "state": "blocked", "cwd": "/e"}
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
plain() { sed $'s/\e\\[[0-9;]*m//g'; }

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
check "which: Claude's own fields ride along" \
  "$(jaq -c '.[] | select(.pid == 111) | [.status, .turn_status, .task_state, .name, .short_id, .started]' <<<"$which_json")" \
  '["busy","busy",null,"alpha-work",null,0]'
check "which view: name column" "$(run "$bin/zmx-which" alpha | plain | sed -n 2p | sed 's/  */ /g')" \
  "111 interactive busy alpha 1 label alpha-work /a"
check "which: filter by session" "$(run "$bin/zmx-which" --json alpha | jaq -r 'map(.pid) | join(",")')" "111"
check "which: filter by pid" "$(run "$bin/zmx-which" --json 311 | jaq -r 'map(.zmx_session) | join(",")')" "gamma"

# --- agent-sessions: contract ------------------------------------------------
as_json=$(run "$bin/agent-sessions" --json --within 0)
check "agent-sessions: association carried" \
  "$(jaq -c '[.[] | select(.source == "claude") | [.pid, .zmx_session, .association_source, .occ]]' <<<"$as_json")" \
  '[[111,"alpha","label","active"],[311,"gamma","process_env","active"],[411,"delta","process_tree","active"],[999,null,null,null],[null,null,null,null]]'
check "agent-sessions: status by kind, short id from id" \
  "$(jaq -c '[.[] | select(.pid == 111 or .pid == null) | [.kind, .status, .short_id, .idle_s]]' <<<"$as_json")" \
  '[["interactive","busy",null,null],["background","blocked","bg",null]]'
check "agent-sessions: every contract key, in order" "$(jaq -r '.[0] | keys_unsorted | join(",")' <<<"$as_json")" \
  "source,kind,status,pid,session_id,short_id,name,cwd,branch,zmx_session,association_source,occ,idle_s,started,turn_status,task_state"
check "agent-sessions: merged status beside Claude's status and state" \
  "$(jaq -c '[.[] | select(.pid == 111 or .pid == null) | [.status, .turn_status, .task_state]]' <<<"$as_json")" \
  '[["busy","busy",null],["blocked","idle","blocked"]]'
check "agent-sessions: --within 0 has no Codex row" "$(jaq '[.[] | select(.source == "codex")] | length' <<<"$as_json")" "0"
check "agent-sessions: Codex row" \
  "$(run "$bin/agent-sessions" --json --within 60 |
    jaq -c '[.[] | select(.source == "codex") | [.kind, .status, .session_id, .short_id, .cwd, .branch, .pid, (.idle_s < 60)]]')" \
  '[["codex","idle","0199aaaa-bbbb-cccc","0199aaaa","/work/app","feat/y",null,true]]'
check "agent-sessions: --json wins over --watch" "$(run "$bin/agent-sessions" --watch --json --within 0 | jaq length)" "5"
run "$bin/agent-sessions" --bogus >/dev/null 2>&1
check "agent-sessions: an unknown flag exits 2" "$?" "2"

as_view=$(run "$bin/agent-sessions" --within 60 | plain)
check "agent-sessions view: waiting sorts first" "$(sed -n 2p <<<"$as_view" | sed 's/  */ /g')" "● cc c delta waiting active -"
check "agent-sessions view: Codex row shows its short id" "$(rg -c '^● cx app feat/y\s+-\s+\d+s\s+-\s+0199aaaa$' <<<"$as_view")" "1"
check "agent-sessions view: an agent's name follows its branch" "$(rg -c '^● cc a\s+alpha-work alpha\s+busy\s+active\s+-$' <<<"$as_view")" "1"
check "agent-sessions view: background task" "$(rg -c '^  \(unnamed\) bg blocked$' <<<"$as_view")" "1"

# --- mission-control: view ----------------------------------------------------
mc_view=$(run "$bin/mission-control" --within 60 | plain)
check "mission-control: header" "$(sed -n 1p <<<"$mc_view")" " mission control"
check "mission-control: waiting agent first, with its host" "$(sed -n 2p <<<"$mc_view" | sed 's/  */ /g')" "● cc c waiting delta"
check "mission-control: busy agent hosted by alpha" "$(rg -c '^● cc  a\s+alpha-work busy\s+alpha$' <<<"$mc_view")" "1"
check "mission-control: Codex row between busy and idle" "$(sed -n 4p <<<"$mc_view" | rg -c '^● cx  app feat/y\s+\d+s$')" "1"
check "mission-control: pid-less agent is not listed" "$(rg -c ' cc ' <<<"$mc_view")" "4"
check "mission-control: only the session hosting no agent is an orphan" \
  "$(rg ' zmx ' <<<"$mc_view" | sed 's/  */ /g')" "◦ zmx tmp detached beta"
check "mission-control: workspace tag by decoded directory" \
  "$(: >"$fix/agents.json" && run "$bin/mission-control" --within 0 | plain | rg 'alpha' | sed 's/  */ /g')" \
  "● zmx proj a shell alpha ·main"
run "$bin/mission-control" --json >/dev/null 2>&1
check "mission-control: an unknown flag exits 2" "$?" "2"

# --- zmx-reap: verdicts -------------------------------------------------------
# epsilon: detached like beta, but with work in its tree. It joins the fixtures
# here so the checks above keep the sessions they were written against.
printf '%s\n' $'  name=epsilon\tpid=500\tclients=0\tcreated=1000\tcwd=/work' >>"$fix/zmx-list"
printf '%s\n' '501 500 01:00 100 -zsh' '511 501 01:00 100 sleep 60' >>"$fix/ps-table"

table() { plain | sed 's/  */ /g; s/ $//'; }
sessions() { rg -o '^(alpha|beta|gamma|delta|epsilon)\b' | paste -sd, -; }
reap_out=$(run "$bin/zmx-reap" 2>/dev/null | table)
check "reap: detached and idle is reaped" "$(rg -c '^beta \d+d reap /tmp$' <<<"$reap_out")" "1"
check "reap: detached with work is skipped, and says what runs" "$(rg -c '^epsilon \d+d active:sleep /work$' <<<"$reap_out")" "1"
check "reap: attached sessions are not listed" "$(sessions <<<"$reap_out")" "beta,epsilon"
check "reap: bold header" "$(sed -n 1p <<<"$reap_out")" "NAME AGE VERDICT DIR"
check "reap: dry-run summary" \
  "$(rg -c '^1 reapable, 1 active \+ 3 attached skipped . dry run\. Re-run with --kill to execute\.$' <<<"$reap_out")" "1"
check "reap: a dry run kills nothing" "$([[ -e "$fix/killed" ]] && echo killed || echo none)" "none"
reap_all=$(run "$bin/zmx-reap" --all 2>/dev/null | table)
check "reap: --all lists attached sessions" "$(sessions <<<"$reap_all")" "alpha,beta,gamma,delta,epsilon"
check "reap: --all marks them attached" "$(rg -c '^\S+ \d+d attached( |$)' <<<"$reap_all")" "3"
kill_out=$(run "$bin/zmx-reap" -k 2>/dev/null | table)
check "reap: --kill reports what it killed" "$(sed -n '$p' <<<"$kill_out")" "killed 1 session(s), 1 active + 3 attached skipped"
check "reap: --kill kills only the reapable session" "$(cat "$fix/killed" 2>/dev/null)" "beta"
run "$bin/zmx-reap" --bogus >/dev/null 2>&1
check "reap: an unknown flag exits 2" "$?" "2"

# --- zmx-env ------------------------------------------------------------------
env_out=$(run "$bin/zmx-env" alpha | plain)
check "env: one block per process" "$(rg '^== ' <<<"$env_out" | paste -sd, -)" "== alpha 101 (-zsh),== alpha 111 (claude)"
check "env: entries sorted" "$(rg '^[A-Z_]+=' <<<"$env_out" | paste -sd, -)" "TERM=x,ZMX_SESSION=beta"
check "env: a hidden environment says so" "$(rg -c '^\(no env visible' <<<"$env_out")" "1"
check "env: patterns filter, case-insensitively" \
  "$(run "$bin/zmx-env" alpha zmx_ | plain | rg '^[A-Z_]+=' | paste -sd, -)" "ZMX_SESSION=beta"
run "$bin/zmx-env" nope >/dev/null 2>&1
check "env: an unknown session exits 1" "$?" "1"
run "$bin/zmx-env" >/dev/null 2>&1
check "env: no session exits 2" "$?" "2"
run "$bin/zmx-env" alpha '(' >/dev/null 2>&1
check "env: a bad pattern exits 2" "$?" "2"

# --- zmx-select: the rows fzf lists -------------------------------------------
emit=$(run "$bin/zmx-select" --emit)
check "select: current session hidden, grouped by directory" \
  "$(awk '{ print $1 }' <<<"$emit" | paste -sd, -)" "delta,gamma,beta,epsilon"
check "select: row columns" "$(rg '^beta ' <<<"$emit" | sed 's/  */ /g')" "beta /tmp idle - cl:0 pid:200"
check "select: --here keeps this directory's sessions" \
  "$(run env PWD=/tmp "$bin/zmx-select" --here --emit | awk '{ print $1 }' | paste -sd, -)" "beta"
check "select: sessions in this directory come first" \
  "$(run env PWD=/work "$bin/zmx-select" --emit | awk 'NR == 1 { print $1 }')" "epsilon"
run "$bin/zmx-select" --bogus >/dev/null 2>&1
check "select: an unknown flag exits 2" "$?" "2"

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
