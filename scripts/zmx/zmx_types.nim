## Domain and wire types shared by the zmx tools.
##
## Domain types (`ZmxSession`, `ProcessInfo`, `AgentSession`) carry `distinct`
## identifiers and whatever the readers learned. Wire types (`SessionOut`,
## `ProcOut`, `WhichOut`, `AgentOut`) are the JSON contract the Bash siblings
## and `jaq` pipelines read; `ZmxJson` encodes them with absent optionals
## written as `null`. The `*In` types are what `ClaudeJson` decodes from other
## tools' output: `bmx list --json`, `claude agents --json`, a Codex rollout's
## first line, `wezterm cli list --format json`, and an agent hook's stdin.

import std/[options, tables]
import json_serialization
import json_serialization/std/[options as jsOptions, tables as jsTables]

export options, tables, json_serialization, jsOptions, jsTables

type
  ZmxSessionName* = distinct string
  ProcessId* = distinct int

  SessionOccupancy* = enum
    ## Whether a session's process tree holds a real workload. This is not an
    ## agent's turn status.
    soActive = "active"
    soIdle = "idle"

  ReapVerdict* = enum
    ## What `zmx-reap` does with a session.
    rvReap = "reap"
    rvActive = "active"
    rvAttached = "attached"

  ProcessInfo* = object
    pid*, ppid*: ProcessId
    startedAt*: Option[int64]
      ## epoch seconds; none when the kernel withholds it (a root-owned process)
    rssKb*: Option[int]
    argv*: seq[string] ## empty when the kernel withholds it
    command*: string ## argv joined, or the short name

  ZmxSession* = object
    name*: ZmxSessionName
    pid*: ProcessId
    clients*: int
    created*: int64
    cwd*: string
    current*: bool
    labels*: OrderedTable[string, string]

  ProcOut* = object
    pid*: int
    etime*: Option[string]
    rssKb* {.serializedFieldName("rss_kb").}: Option[int]
    command*: string

  SessionOut* = object
    name*: string
    pid*, clients*: int
    created*: int64
    cwd*: string
    current*: bool
    labels*: OrderedTable[string, string]
    ageS* {.serializedFieldName("age_s").}: int64
    procs*: seq[ProcOut]
    state*: SessionOccupancy
    running*: Option[string]

  ClaudeSessionId* = distinct string

  AssociationSource* = enum
    ## How an agent was matched to its zmx session.
    asLabel = "label"
    asProcessEnv = "process_env"
    asProcessTree = "process_tree"

  CodexSessionId* = distinct string

  AgentProvider* = enum
    apClaude = "claude"
    apCodex = "codex"

  AgentKind* = enum
    akInteractive = "interactive"
    akBackground = "background"
    akCodex = "codex"
    akOther = "other"

  AgentStatus* = enum
    ## An agent's turn status. The order is the sort order.
    asWaiting = "waiting"
    asBusy = "busy"
    asIdle = "idle"
    asOther = "other"

  AgentSession* = object
    ## One `claude agents` entry. `kind`, `status` and `state` stay strings:
    ## Claude owns those sets, and `--json` echoes them back. `kindOf` and
    ## `turnStatusOf` in `zmx_agents` classify them.
    pid*: Option[ProcessId]
    kind*: Option[string]
    status*: Option[string] ## an interactive agent's turn status
    state*: Option[string] ## a background agent's task state
    sessionId*: Option[ClaudeSessionId]
    shortId*, name*, cwd*: Option[string]
    startedAt*: Option[int64] ## epoch seconds

  ClaudeAgentIn* = object
    pid*: Option[int]
    kind*, status*, state*, sessionId*, id*, name*, cwd*: Option[string]
    startedAt*: Option[int64] ## epoch milliseconds

  WhichOut* = object
    pid*: int
    kind*: Option[string]
    status*: string ## merged, as in `AgentOut`
    sessionId* {.serializedFieldName("session_id").}: Option[string]
    cwd*: Option[string]
    zmxSession* {.serializedFieldName("zmx_session").}: Option[string]
    associationSource* {.serializedFieldName("association_source").}:
      Option[AssociationSource]
    clients*: Option[int]
    occ*: Option[SessionOccupancy]
    turnStatus* {.serializedFieldName("turn_status").}: Option[string]
      ## Claude's `status`, as sent
    taskState* {.serializedFieldName("task_state").}: Option[string]
      ## Claude's `state`, as sent
    name*: Option[string]
    shortId* {.serializedFieldName("short_id").}: Option[string]
    started*: int64

  AgentOut* = object ## One `agent-sessions --json` row.
    source*: AgentProvider
    kind*: string
    status*: string
      ## merged: an interactive agent's turn status, any other agent's task state
    pid*: Option[int]
    sessionId* {.serializedFieldName("session_id").}: Option[string]
    shortId* {.serializedFieldName("short_id").}: Option[string]
    name*, cwd*, branch*: Option[string]
    zmxSession* {.serializedFieldName("zmx_session").}: Option[string]
    associationSource* {.serializedFieldName("association_source").}:
      Option[AssociationSource]
    occ*: Option[SessionOccupancy]
    idleS* {.serializedFieldName("idle_s").}: Option[int64]
    started*: int64
    turnStatus* {.serializedFieldName("turn_status").}: Option[string]
      ## Claude's `status`, as sent
    taskState* {.serializedFieldName("task_state").}: Option[string]
      ## Claude's `state`, as sent

  CodexGitIn* = object
    branch*: Option[string]

  CodexPayloadIn* = object
    id*, cwd*: Option[string]
    git*: Option[CodexGitIn]

  CodexMetaIn* = object ## Line one of a Codex rollout file.
    payload*: Option[CodexPayloadIn]

  WeztermPaneIn* = object
    cwd*, workspace*: Option[string]

  BmxRowIn* = object
    ## One `bmx list --json` row. A bmx host's session and a zmx daemon's read
    ## the same; a row the client could not probe has no pid.
    name*: Option[string]
    pid*, clients*: Option[int]
    createdAt* {.serializedFieldName("created_at").}: Option[string] ## RFC 3339, UTC
    cwd*: Option[string]
    labels*: Option[OrderedTable[string, string]]

  HookIn* = object ## An agent hook's stdin; only the session id is read.
    sessionId* {.serializedFieldName("session_id").}: Option[string]

createJsonFlavor ZmxJson,
  omitOptionalFields = false, automaticObjectSerialization = true

createJsonFlavor ClaudeJson,
  allowUnknownFields = true, automaticObjectSerialization = true

func `==`*(a, b: ZmxSessionName): bool {.borrow.}
func `$`*(a: ZmxSessionName): string {.borrow.}
func `==`*(a, b: ClaudeSessionId): bool {.borrow.}
func `$`*(a: ClaudeSessionId): string {.borrow.}
func `==`*(a, b: CodexSessionId): bool {.borrow.}
func `$`*(a: CodexSessionId): string {.borrow.}
func `==`*(a, b: ProcessId): bool {.borrow.}
func `$`*(a: ProcessId): string {.borrow.}
