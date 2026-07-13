## Host-agent identification from the environment.
##
## Shared by `notify.nim` (notification-identifier namespace) and the anchor
## hooks (`--agent` fallback). No binary of its own.

import std/[os, strutils]

# Per-agent detection for the notification-identifier namespace, so concurrent
# sessions of different agents (and the dismiss that clears them) never collide.
#
# Documented, tool-specific signals come FIRST because they're the reliable
# ones — CLAUDECODE is the env var Anthropic actually documents and commits to.
# The generic slug vars below are the fallback catch:
#   - AI_AGENT  — undocumented/observed-only; Claude Code sets
#     `claude-code_2-1-183_agent` (slug_version_agent), but it's absent from the
#     official env-vars reference and could change without notice.
#   - AGENT     — the emerging cross-agent convention (Goose/Amp set a slug),
#     but its value is contested (some tools set AGENT=1 as a boolean) and
#     Claude Code declined to adopt it (anthropics/claude-code#24838).
# Extend by appending a marker row (preferred) or relying on AGENT/AI_AGENT.
const
  agentMarkers* = [
    ("LULU_AGENT", "lulu"),
      # our own agent's base indicator (lulu-agent: AgentIdentity.env_vars,
      # always "1" for any lulu-spawned subprocess; session id NOT guaranteed)
    ("CLAUDECODE", "claude-code"), # documented, stable
    ("CURSOR_AGENT", "cursor"),
    ("GEMINI_CLI", "gemini"),
    ("CODEX_SANDBOX", "codex"),
    ("GOOSE_TERMINAL", "goose"),
  ]
  genericAgentVars* = ["AGENT", "AI_AGENT"]

proc slugFromGeneric*(v: string): string =
  ## Slug from a generic AGENT/AI_AGENT value (leading token before `_`),
  ## ignoring the boolean forms some tools use. "" when not slug-like.
  if v.len == 0 or v in ["1", "true", "0", "false"]:
    return ""
  v.split('_')[0]

proc agentSlug*(): string =
  ## Identifies the host agent. Documented markers first, then the generic
  ## slug vars, then "luna".
  for (envVar, slug) in agentMarkers:
    if getEnv(envVar).len > 0:
      return slug
  for envVar in genericAgentVars:
    let slug = slugFromGeneric(getEnv(envVar))
    if slug.len > 0:
      return slug
  "luna"
