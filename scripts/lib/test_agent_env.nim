import std/[os, unittest]
import ./agent_env

proc clearAll() =
  for (envVar, _) in agentMarkers:
    delEnv(envVar)
  for envVar in genericAgentVars:
    delEnv(envVar)

suite "slugFromGeneric":
  test "rejects boolean forms":
    for v in ["", "1", "true", "0", "false"]:
      check slugFromGeneric(v) == ""

  test "takes the leading token before the first underscore":
    check slugFromGeneric("claude-code_2-1-183_agent") == "claude-code"
    check slugFromGeneric("goose") == "goose"

suite "agentSlug":
  setup:
    clearAll()

  teardown:
    clearAll()

  test "falls back to luna when nothing is set":
    check agentSlug() == "luna"

  test "documented markers win over the generic vars":
    putEnv("AI_AGENT", "cursor_1_agent")
    putEnv("CLAUDECODE", "1")
    check agentSlug() == "claude-code"

  test "marker order decides when several are set":
    putEnv("CLAUDECODE", "1")
    putEnv("LULU_AGENT", "1")
    check agentSlug() == "lulu"

  test "generic vars are used when no marker is set":
    putEnv("AI_AGENT", "claude-code_2-1-183_agent")
    check agentSlug() == "claude-code"

  test "a boolean generic var does not become a slug":
    putEnv("AGENT", "1")
    check agentSlug() == "luna"
