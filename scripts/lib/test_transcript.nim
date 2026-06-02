import std/[options, os, sequtils, strutils, times, unittest]
import ./transcript

const Fixture = """
{"type":"user","isSidechain":false,"timestamp":"t1","message":{"role":"user","content":"hello there"}}
{"type":"assistant","isSidechain":false,"timestamp":"t2","message":{"role":"assistant","content":[{"type":"text","text":"hi"},{"type":"tool_use","name":"Bash"}]}}
{"type":"user","isSidechain":false,"toolUseResult":{"ok":1},"message":{"role":"user","content":[{"type":"tool_result","content":"cmd output"}]}}
{"type":"user","isSidechain":false,"message":{"role":"user","content":"<command-name>/compact</command-name>"}}
{"type":"user","isSidechain":false,"message":{"role":"user","content":"<local-command-stdout>done</local-command-stdout>"}}
{"type":"user","isSidechain":false,"isCompactSummary":true,"message":{"role":"user","content":"summary blob"}}
{"type":"user","isSidechain":true,"message":{"role":"user","content":"subagent chatter"}}
{"type":"user","isSidechain":false,"isMeta":true,"message":{"role":"user","content":"meta note"}}
{"type":"system","content":"system line"}
{"type":"last-prompt","lastPrompt":"ignored shortcut"}
{"type":"user","isSidechain":false,"timestamp":"t3","message":{"role":"user","content":[{"type":"text","text":"second question"}]}}
{"type":"assistant","isSidechain":false,"timestamp":"t4","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read"}]}}
{"type":"user","isSidechain":false,"timestamp":"t5","message":{"role":"user","content":"last thing"}}
"""

proc writeFixture(): string =
  result = getTempDir() / "convo_fixture_test.jsonl"
  writeFile(result, Fixture.strip() & "\n")

proc setupListProjects(home: string) =
  let a = home / ".claude" / "projects" / "-proj-alpha"
  let b = home / ".claude" / "projects" / "-proj-beta"
  createDir(a)
  createDir(b)
  writeFile(a / "aaa.jsonl", "{}\n")
  writeFile(b / "bbb.jsonl", "{}\n")
  setLastModificationTime(a / "aaa.jsonl", fromUnix(1_000_000))
  setLastModificationTime(b / "bbb.jsonl", fromUnix(2_000_000))

suite "transcript":
  let path = writeFixture()

  test "projectSlug maps / and . to -":
    check projectSlug("/Users/jamesbombeelu/.local/share/chezmoi") ==
      "-Users-jamesbombeelu--local-share-chezmoi"

  test "default parse keeps only genuine conversation turns":
    let turns = parseTranscript(path)
    check turns.len == 4
    check turns[0].role == "user"
    check turns[0].text == "hello there"
    check turns[1].role == "assistant"
    check turns[1].text == "hi"
    check turns[2].text == "second question"
    check turns[3].text == "last thing"

  test "lastUserMessage returns the final user turn":
    check lastUserMessage(parseTranscript(path)) == some("last thing")

  test "lastUserMessages returns last N user texts in order":
    let turns = parseTranscript(path)
    check lastUserMessages(turns, 2) == @["second question", "last thing"]
    check lastUserMessages(turns, 1) == @["last thing"]
    check lastUserMessages(turns, 0).len == 0

  test "recentTurns returns the last n in order":
    let turns = parseTranscript(path)
    let r = recentTurns(turns, 2)
    check r.len == 2
    check r[0].text == "second question"
    check r[1].text == "last thing"
    check recentTurns(turns, 0).len == 0

  test "includeToolNoise re-includes tool results and tool_use markers":
    let turns = parseTranscript(path, includeToolNoise = true)
    check turns.len > 4
    check turns.anyIt(it.text.contains("cmd output"))
    check turns.anyIt(it.text.contains("[tool_use: Bash]"))

  test "missing file yields no turns":
    check parseTranscript(getTempDir() / "convo_nope_xyz.jsonl").len == 0

  test "currentTranscriptPath returns the NEWEST jsonl by mtime":
    let tmpHome = getTempDir() / "convo_home_test"
    let projDir = tmpHome / ".claude" / "projects" / projectSlug("/tmp/proj")
    createDir(projDir)
    writeFile(projDir / "older.jsonl", "{}\n")
    writeFile(projDir / "newer.jsonl", "{}\n")
    # Deterministic mtimes so the test proves newest-wins, not just single-file.
    setLastModificationTime(projDir / "older.jsonl", fromUnix(1_000_000))
    setLastModificationTime(projDir / "newer.jsonl", fromUnix(2_000_000))
    let prev = getEnv("HOME")
    putEnv("HOME", tmpHome)
    let found = currentTranscriptPath("/tmp/proj")
    putEnv("HOME", prev)
    check found.isSome
    check found.get.endsWith("newer.jsonl")
    removeDir(tmpHome)

  removeFile(path)

suite "listTranscripts":
  test "enumerates all projects, newest mtime first":
    let home = getTempDir() / "convo_list_all"
    removeDir(home)
    setupListProjects(home)
    let prev = getEnv("HOME")
    putEnv("HOME", home)
    let rows = listTranscripts()
    putEnv("HOME", prev)
    check rows.len == 2
    check rows[0].sessionId == "bbb" # newer mtime first
    check rows[1].sessionId == "aaa"
    check rows[0].project == "-proj-beta"
    check rows[0].size == 3 # "{}\n"
    removeDir(home)

  test "project filter keeps only matching slugs":
    let home = getTempDir() / "convo_list_filter"
    removeDir(home)
    setupListProjects(home)
    let prev = getEnv("HOME")
    putEnv("HOME", home)
    let rows = listTranscripts("alpha")
    putEnv("HOME", prev)
    check rows.len == 1
    check rows[0].project == "-proj-alpha"
    removeDir(home)

  test "since/until bound by mtime":
    let home = getTempDir() / "convo_list_time"
    removeDir(home)
    setupListProjects(home)
    let prev = getEnv("HOME")
    putEnv("HOME", home)
    let onlyNew = listTranscripts("", some(fromUnix(1_500_000)), none(Time))
    let onlyOld = listTranscripts("", none(Time), some(fromUnix(1_500_000)))
    putEnv("HOME", prev)
    check onlyNew.len == 1
    check onlyNew[0].sessionId == "bbb"
    check onlyOld.len == 1
    check onlyOld[0].sessionId == "aaa"
    removeDir(home)

  test "missing projects root yields empty":
    let home = getTempDir() / "convo_list_empty_xyz"
    removeDir(home)
    let prev = getEnv("HOME")
    putEnv("HOME", home)
    let rows = listTranscripts()
    putEnv("HOME", prev)
    check rows.len == 0
