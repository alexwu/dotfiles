## Fixtures for tool_failure_log's leading-program matcher.
##   nim r scripts/claude/test_tool_failure_log.nim

import std/[os, strutils]
import unittest
import tool_failure_log

type Case = object
  name: string
  cmd: string
  fires: bool

const cases = [
  # ── must match ────────────────────────────────────────────────────────────
  Case(name: "bare tool", cmd: "memo cargo test", fires: true),
  Case(name: "env prefix", cmd: "FOO=bar memo cargo test", fires: true),
  Case(
    name: "env prefix, quoted value with spaces",
    cmd: "TOKEN='v with spaces' memo cargo test",
    fires: true,
  ),
  Case(name: "multiple env prefixes", cmd: "A=1 B=2 chain -- a b", fires: true),
  Case(name: "leading whitespace", cmd: "   hark ls", fires: true),
  Case(name: "second line", cmd: "cd /x\nmemo build", fires: true),
  Case(name: "other tools", cmd: "tokens 'count me'", fires: true),
  Case(name: "image gen", cmd: "image gen -o out.png 'a cat'", fires: true),

  # ── must NOT match ────────────────────────────────────────────────────────
  Case(
    name: "tool name inside a quoted string",
    cmd: "echo \"memo is a tool\"",
    fires: false,
  ),
  Case(name: "tool name as an argument", cmd: "rg memo src/", fires: false),
  Case(
    name: "tool name in a commit message",
    cmd: "git commit -m \"chain of events\"",
    fires: false,
  ),
  Case(
    name: "tool name as a path component",
    cmd: "cat crates/memo/src/main.rs",
    fires: false,
  ),
  Case(name: "longer word with tool prefix", cmd: "memoize --help", fires: false),
  Case(name: "unrelated command", cmd: "cargo test --workspace", fires: false),
]

suite "tool_failure_log: leading-program matcher":
  test "fixtures":
    for c in cases:
      checkpoint(c.name & " :: " & c.cmd.replace("\n", "\\n"))
      check isToolInvocation(c.cmd) == c.fires

  test "ACCEPTED false positive: tool name opening a heredoc line":
    # Documented v1 tradeoff (see the plan's Risks + the hook's toolRe comment):
    # reMultiLine cannot tell a heredoc body from a real command line, so this
    # DOES match and costs one spurious log record the miner then discards.
    # Pinned deliberately — a future ast_bash upgrade should flip this
    # consciously, not by accident.
    check isToolInvocation("cat <<EOF\nmemo inside heredoc\nEOF")

suite "tool_failure_log: log path":
  test "honors XDG_STATE_HOME when set":
    putEnv("XDG_STATE_HOME", "/tmp/xdg-test")
    check logPath() == "/tmp/xdg-test/lulu-tools/tool-failures.jsonl"

  test "falls back to ~/.local/state when XDG_STATE_HOME is empty":
    putEnv("XDG_STATE_HOME", "")
    check logPath() ==
      getHomeDir() / ".local" / "state" / "lulu-tools" / "tool-failures.jsonl"
