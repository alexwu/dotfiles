import std/[options, os, strutils, unittest]
import parsetoml
import ./anchor

# Canonical: `resolveFromManifest` resolves the manifest through symlinks, and
# on macOS $TMPDIR is itself a symlink (/var -> /private/var). Comparing raw
# `getTempDir()` paths against resolved ones would fail for the wrong reason.
let fixtureDir = expandFilename(getTempDir()) / "anchor_fixture_test"

proc rule(toml: string): TomlValueRef =
  ## Parse a single `[[persona]]` table and hand back the rule itself.
  parsetoml.parseString(toml).getOrDefault("persona").getElems[0]

proc writeManifest(body: string) =
  createDir(fixtureDir)
  writeFile(fixtureDir / "anchors.toml", body)
  putEnv("ANCHORS_MANIFEST", fixtureDir / "anchors.toml")

proc touch(name: string) =
  createDir((fixtureDir / name).parentDir)
  writeFile(fixtureDir / name, "body\n")

suite "isUnder":
  test "self-match":
    check isUnder("/a/b", "/a/b")

  test "true child":
    check isUnder("/a/b/c", "/a/b")

  test "respects component boundaries":
    check not isUnder("/a/bc", "/a/b")

  test "expands ~ on both sides":
    check isUnder(getHomeDir() / "Code", "~/Code")
    check isUnder("~/Code/x", getHomeDir() / "Code")

suite "ruleMatches":
  test "no when clause is an unconditional catch-all":
    check rule("[[persona]]\nfile = \"a.md\"\n").ruleMatches("/anywhere", "codex")

  test "when keys AND together":
    let r = rule(
      "[[persona]]\nwhen = { cwd_under = \"/w\", agent = \"codex\" }\nfile = \"a.md\"\n"
    )
    check r.ruleMatches("/w/sub", "codex")
    check not r.ruleMatches("/w/sub", "claude-code")
    check not r.ruleMatches("/elsewhere", "codex")

  test "array form of cwd_under is any-match":
    let r =
      rule("[[persona]]\nwhen = { cwd_under = [\"/x\", \"/y\"] }\nfile = \"a.md\"\n")
    check r.ruleMatches("/y/deep", "lu")
    check not r.ruleMatches("/z", "lu")

  test "array form of agent is any-match":
    let r =
      rule("[[persona]]\nwhen = { agent = [\"codex\", \"lu\"] }\nfile = \"a.md\"\n")
    check r.ruleMatches("/anywhere", "lu")
    check not r.ruleMatches("/anywhere", "claude-code")

suite "resolveFromManifest":
  setup:
    removeDir(fixtureDir)
    createDir(fixtureDir)

  teardown:
    delEnv("ANCHORS_MANIFEST")
    removeDir(fixtureDir)

  test "no manifest resolves to none":
    putEnv("ANCHORS_MANIFEST", fixtureDir / "absent.toml")
    check resolveFromManifest("persona", "/w", "codex").isNone

  test "malformed TOML resolves to none rather than raising":
    writeManifest("[[persona]\nfile = ")
    check resolveFromManifest("persona", "/w", "codex").isNone

  test "missing kind resolves to none":
    writeManifest("[[reward]]\nfile = \"r.md\"\n")
    touch("r.md")
    check resolveFromManifest("persona", "/w", "codex").isNone

  test "first matching rule wins and file resolves against the manifest dir":
    touch("first.md")
    touch("second.md")
    writeManifest(
      "[[persona]]\nfile = \"first.md\"\n\n[[persona]]\nfile = \"second.md\"\n"
    )
    let r = resolveFromManifest("persona", "/w", "codex")
    check r.isSome
    check r.get.path == fixtureDir / "first.md"
    check not r.get.skip

  test "a matched rule with a missing file falls through to the next":
    touch("present.md")
    writeManifest(
      "[[persona]]\nfile = \"typo.md\"\n\n[[persona]]\nfile = \"present.md\"\n"
    )
    let r = resolveFromManifest("persona", "/w", "codex")
    check r.isSome
    check r.get.path == fixtureDir / "present.md"

  test "every rule missing its file resolves to none":
    writeManifest("[[persona]]\nfile = \"typo.md\"\n")
    check resolveFromManifest("persona", "/w", "codex").isNone

  test "skip short-circuits and does not fall through":
    touch("catchall.md")
    writeManifest(
      "[[reward]]\nwhen = { cwd_under = \"/work\" }\nskip = true\n\n" &
        "[[reward]]\nfile = \"catchall.md\"\n"
    )
    let skipped = resolveFromManifest("reward", "/work/repo", "claude-code")
    check skipped.isSome
    check skipped.get.skip
    check skipped.get.path == ""
    let fellThrough = resolveFromManifest("reward", "/work-other", "claude-code")
    check fellThrough.isSome
    check fellThrough.get.path == fixtureDir / "catchall.md"

  test "a symlinked manifest resolves `file` against its target's directory":
    # The real deployment shape: ~/.claude/anchors/anchors.toml is a symlink
    # into the prompts repo, and the bodies sit next to the target.
    let linkDir = fixtureDir / "link"
    createDir(linkDir)
    touch("real.md")
    writeFile(fixtureDir / "anchors.toml", "[[persona]]\nfile = \"real.md\"\n")
    createSymlink(fixtureDir / "anchors.toml", linkDir / "anchors.toml")
    putEnv("ANCHORS_MANIFEST", linkDir / "anchors.toml")
    let r = resolveFromManifest("persona", "/w", "codex")
    check r.isSome
    check r.get.path == fixtureDir / "real.md"

  test "agent selects between variants":
    touch("codex.md")
    touch("default.md")
    writeManifest(
      "[[persona]]\nwhen = { agent = \"codex\" }\nfile = \"codex.md\"\n\n" &
        "[[persona]]\nfile = \"default.md\"\n"
    )
    check resolveFromManifest("persona", "/w", "codex").get.path ==
      fixtureDir / "codex.md"
    check resolveFromManifest("persona", "/w", "lu").get.path ==
      fixtureDir / "default.md"

suite "resolveAnchor":
  setup:
    removeDir(fixtureDir)
    createDir(fixtureDir)

  teardown:
    delEnv("ANCHORS_MANIFEST")
    delEnv("TEST_ANCHOR_FILE")
    removeDir(fixtureDir)

  test "the env override beats the manifest":
    touch("manifest.md")
    touch("override.md")
    writeManifest("[[persona]]\nfile = \"manifest.md\"\n")
    putEnv("TEST_ANCHOR_FILE", fixtureDir / "override.md")
    let r = resolveAnchor("persona", "TEST_ANCHOR_FILE", "nope.md", "/w", "codex")
    check r.path == fixtureDir / "override.md"

  test "no manifest match falls back to the legacy path":
    writeManifest("[[persona]]\nfile = \"typo.md\"\n")
    # `legacyRelPath` is joined onto $HOME, so the fixture has to live there.
    let legacy = ".cache" / "anchor_test_legacy.md"
    createDir((getHomeDir() / legacy).parentDir)
    writeFile(getHomeDir() / legacy, "legacy\n")
    defer:
      removeFile(getHomeDir() / legacy)
    let r = resolveAnchor("persona", "TEST_ANCHOR_FILE", legacy, "/w", "codex")
    check r.path == getHomeDir() / legacy

  test "nothing anywhere resolves to an empty path":
    putEnv("ANCHORS_MANIFEST", fixtureDir / "absent.toml")
    let r = resolveAnchor(
      "persona", "TEST_ANCHOR_FILE", "definitely/not/here.md", "/w", "codex"
    )
    check r.path == ""
    check not r.skip

suite "applyTemplate":
  test "substitutes every pair":
    check applyTemplate("<A> and <B>", {"<A>": "x", "<B>": "y"}) == "x and y"

  test "leaves unknown placeholders alone":
    check applyTemplate("<A> <C>", {"<A>": "x"}) == "x <C>"

suite "counter state":
  const
    sd = "anchor_test_state"
    sid = "roundtrip_fixture"
  let statePath = getHomeDir() / ".claude" / sd / (sid & ".json")

  teardown:
    removeFile(statePath)

  test "count, resets, and last_fired_at round-trip":
    saveState(sd, sid, State(count: 3, resets: 2, lastFiredAt: "t"))
    let s = loadState(sd, sid)
    check s.count == 3
    check s.resets == 2
    check s.lastFiredAt == "t"

  test "zero resets / empty last_fired_at are omitted but load as defaults":
    saveState(sd, sid, State(count: 1))
    let s = loadState(sd, sid)
    check s.count == 1
    check s.resets == 0
    check s.lastFiredAt == ""
    check "resets" notin readFile(statePath)
