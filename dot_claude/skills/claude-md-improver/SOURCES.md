# Sources

This skill is a fork+rewrite of Anthropic's `claude-md-management` plugin, refreshed against the current Claude Code memory model. Re-sync against these upstreams when Claude Code memory features change.

## Upstreams to re-check

| Source | URL | What it gives us |
|---|---|---|
| Original plugin (Anthropic) | https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management | Skill/command shape, original quality rubric, intent |
| Memory documentation | https://code.claude.com/docs/en/memory.md | Authoritative behavior: load order, surfaces, settings, hooks |
| Skills documentation | https://code.claude.com/docs/en/skills.md | When to prefer skills over CLAUDE.md content |
| Settings reference | https://code.claude.com/docs/en/settings.md | `claudeMdExcludes`, `autoMemoryEnabled`, `autoMemoryDirectory` |
| Hooks reference | https://code.claude.com/docs/en/hooks.md | `InstructionsLoaded` hook for debugging |
| Sub-agents reference | https://code.claude.com/docs/en/sub-agents.md | Subagent persistent memory |

## What we changed vs upstream

| Upstream | Ours | Reason |
|---|---|---|
| Discovers `CLAUDE.md` and `.claude.local.md` only | Discovers all 7 surfaces (managed policy, project root, `.claude/CLAUDE.md`, `.claude/rules/`, `CLAUDE.local.md`, user CLAUDE.md, user rules, AGENTS.md, auto-memory dir) | New surfaces shipped after the upstream plugin froze |
| Filename `.claude.local.md` (wrong) | Filename `CLAUDE.local.md` (correct per docs) | Bug fix |
| Knows only `./CLAUDE.md` for project | Knows `./CLAUDE.md` AND `./.claude/CLAUDE.md` are both valid | Doc parity |
| 6-criterion 100-point rubric | Categorical findings (misplaced / oversized / stale / duplicated / conflicting / misnamed / unscoped / missing-import / drifted) | Numeric scores invite rubric-gaming and don't drive useful actions |
| No notion of `.claude/rules/` | First-class — flags content that belongs in path-scoped rules and routes it there | Largest gap in upstream |
| No notion of auto memory | Treats `~/.claude/projects/<proj>/memory/` as Claude-owned and doesn't write to it; only flags duplication between CLAUDE.md and MEMORY.md | Auto memory didn't exist when upstream was written |
| Recommends `#` shortcut | Removed; superseded by auto memory's "Writing memory" flow | Stale UX advice |
| 20pt for "architecture clarity" (rewards growth) | 200-line target check (rewards trimming) | Doc explicitly warns against growing CLAUDE.md |
| No companion decompose tool | Pairs with `/decompose-claude-md` command | Audit without a refactor tool leaves the user holding the bag |

## Last sync

- **Synced**: 2026-05-04
- **Memory doc revision**: matches https://code.claude.com/docs/en/memory.md as of this date
- **Plugin commit**: `ac45fdae4b7af187b5624599ab054090dedadd94`

When re-syncing: refetch the memory doc, diff against this skill's behavior, and bump this date.
