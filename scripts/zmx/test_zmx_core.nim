import std/[posix, sequtils]
import unittest2
import zmx_types, zmx_sessions, proc_table

func pinfo(pid, ppid: int, command: string, argv: seq[string] = @[]): ProcessInfo =
  ProcessInfo(pid: ProcessId(pid), ppid: ProcessId(ppid), command: command, argv: argv)

suite "formatEtime and parseEtime":
  test "ps formats":
    check formatEtime(59) == "00:59"
    check formatEtime(3600) == "01:00:00"
    check formatEtime(2 * 86400 + 3 * 3600 + 4 * 60 + 5) == "2-03:04:05"

  test "round trip":
    for s in [0'i64, 59, 3600, 86399, 86400, 200_000]:
      check parseEtime(formatEtime(s)) == some(s)

  test "garbage":
    check parseEtime("soon").isNone

suite "parsePsOutput":
  test "fields, spaces in the command, elapsed to start time":
    let procs = parsePsOutput(
      "  101   100    01:00    100 -zsh\n  111   101 01:02:03   2048 claude --resume a b\nnonsense\n",
      now = 10_000,
    )
    check procs.len == 2
    check procs[0].pid == ProcessId(101)
    check procs[0].ppid == ProcessId(100)
    check procs[0].startedAt == some(9_940'i64)
    check procs[0].rssKb == some(100)
    check procs[0].command == "-zsh"
    check procs[1].command == "claude --resume a b"
    check procs[1].startedAt == some(10_000'i64 - 3723)

suite "parseProcArgs":
  test "argc strings after the exec path and its padding, env left out":
    let raw = "\x02\x00\x00\x00/bin/zsh\x00\x00\x00-zsh\x00-l\x00HOME=/x\x00"
    check parseProcArgs(raw.toOpenArray(0, raw.high)) == @["-zsh", "-l"]

  test "an argument with spaces stays one argument":
    let raw = "\x01\x00\x00\x00/a b/tool\x00/a b/tool\x00X=1\x00"
    check parseProcArgs(raw.toOpenArray(0, raw.high)) == @["/a b/tool"]

  test "short or empty buffer":
    check parseProcArgs("".toOpenArray(0, -1)).len == 0

suite "descendants":
  let all = @[
    pinfo(301, 300, "-zsh"),
    pinfo(101, 100, "-zsh"),
    pinfo(112, 101, "node"),
    pinfo(111, 101, "claude"),
    pinfo(120, 111, "rg"),
    pinfo(999, 1, "claude"),
  ]

  test "breadth-first, siblings by ascending pid, root excluded":
    check descendants(all, ProcessId(100)).mapIt(int(it.pid)) == @[101, 111, 112, 120]

  test "another root sees only its own tree":
    check descendants(all, ProcessId(300)).mapIt(int(it.pid)) == @[301]

  test "a root with no children":
    check descendants(all, ProcessId(400)).len == 0

suite "occupancy":
  test "shells and atuin's pty proxy are infrastructure":
    check isInfra(pinfo(1, 0, "-zsh"))
    check isInfra(pinfo(1, 0, "/bin/bash -l"))
    check isInfra(pinfo(1, 0, "atuin pty-proxy --shell zsh"))
    check isInfra(pinfo(1, 0, "/opt/homebrew/bin/zsh", @["/opt/homebrew/bin/zsh"]))

  test "anything else is work":
    check not isInfra(pinfo(1, 0, "claude"))
    check not isInfra(pinfo(1, 0, "atuin daemon"))

  test "argv[0] decides when a path has spaces":
    let p =
      pinfo(1, 0, "/Apps/My Tool/zsh-like --x", @["/Apps/My Tool/zsh-like", "--x"])
    check not isInfra(p)

  test "idle tree":
    check occupancy([pinfo(1, 0, "-zsh"), pinfo(2, 1, "atuin pty-proxy")]) ==
      (soIdle, none(string))

  test "active tree names the first working process by base name":
    check occupancy(
      [pinfo(1, 0, "-zsh"), pinfo(2, 1, "/usr/local/bin/claude --resume x")]
    ) == (soActive, some("claude"))

suite "native reader":
  test "this process appears under its parent":
    let procs = readProcesses(psNative, [ProcessId(int(getppid()))])
    check procs.isOk
    let me = procs.get.filterIt(int(it.pid) == int(getpid()))
    check me.len == 1
    check me[0].ppid == ProcessId(int(getppid()))
    check me[0].startedAt.isSome
    check me[0].rssKb.isSome
    check me[0].argv.len > 0

suite "decodeCwd":
  test "file URI with host, percent-encoding and trailing slash":
    check decodeCwd("file://host/Users/x/proj%20a/") == "/Users/x/proj a"

  test "plain path from an older daemon":
    check decodeCwd("/plain") == "/plain"

  test "root keeps its slash":
    check decodeCwd("file://host/") == "/"

suite "parseListLine":
  test "labelled current session":
    let s = parseListLine(
      "→ name=alpha\tpid=100\tclients=1\tcreated=1000\tcwd=file://host/Users/x/proj%20a/\tagent=claude\tclaude_pid=111\tclaude_session=sid-a\trole=reviewer"
    ).get
    check s.name == ZmxSessionName("alpha")
    check s.pid == ProcessId(100)
    check s.clients == 1
    check s.created == 1000
    check s.cwd == "/Users/x/proj a"
    check s.current
    check s.labels.len == 4
    check s.labels["claude_session"] == "sid-a"
    check s.labels["role"] == "reviewer"

  test "run-created session: ended and exit_code are not labels":
    let s = parseListLine(
      "  name=beta\tpid=200\tclients=0\tcreated=1000\tcwd=file://host/tmp\tended=5\texit_code=0"
    ).get
    check s.name == ZmxSessionName("beta")
    check not s.current
    check s.cwd == "/tmp"
    check s.labels.len == 0

  test "cmd is not a label, later fields are":
    let s = parseListLine(
      "  name=gamma\tpid=300\tclients=1\tcreated=1000\tcwd=/plain\tcmd=sleep 5\tagent=claude\tclaude_session=sid-stale"
    ).get
    check s.labels.len == 2
    check s.labels["agent"] == "claude"

  test "no optional fields":
    let s = parseListLine("  name=delta\tpid=400\tclients=2\tcreated=1000").get
    check s.cwd == ""
    check s.clients == 2
    check s.labels.len == 0

  test "unreachable session is skipped":
    check parseListLine("  name=dead\terr=ConnectionRefused\tstatus=unreachable").isNone

  test "a field without = is not a label":
    let s = parseListLine("  name=e\tpid=5\tclients=0\tcreated=1\tstray\tk=v").get
    check s.labels.len == 1
    check s.labels["k"] == "v"

  test "a non-numeric pid is skipped":
    check parseListLine("  name=e\tpid=abc\tclients=0\tcreated=1").isNone

suite "parseList":
  test "keeps reachable sessions in order":
    let sessions = parseList(
      "  name=a\tpid=1\tclients=0\tcreated=1\n  name=dead\terr=X\tstatus=unreachable\n→ name=b\tpid=2\tclients=1\tcreated=2\n"
    )
    check sessions.len == 2
    check sessions[0].name == ZmxSessionName("a")
    check sessions[1].current
