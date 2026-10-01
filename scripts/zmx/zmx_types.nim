## Domain and wire types shared by the zmx tools.
##
## Domain types (`ZmxSession`, `ProcessInfo`) carry `distinct` identifiers and
## whatever the readers learned. Wire types (`SessionOut`, `ProcOut`) are the
## JSON contract the Bash siblings and `jaq` pipelines read; `ZmxJson` encodes
## them with absent optionals written as `null`.

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

createJsonFlavor ZmxJson,
  omitOptionalFields = false, automaticObjectSerialization = true

func `==`*(a, b: ZmxSessionName): bool {.borrow.}
func `$`*(a: ZmxSessionName): string {.borrow.}
func `==`*(a, b: ProcessId): bool {.borrow.}
func `$`*(a: ProcessId): string {.borrow.}
