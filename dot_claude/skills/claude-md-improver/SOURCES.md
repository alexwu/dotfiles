# Sources for re-sync

If Claude Code's memory features change (new surfaces, new load behavior, new file types, new settings keys), refresh this skill against the upstream documentation below.

## Upstream documentation

| Source | URL | Covers |
|---|---|---|
| Memory documentation | https://code.claude.com/docs/en/memory.md | Authoritative behavior: load order, surfaces, settings, hooks |
| Skills documentation | https://code.claude.com/docs/en/skills.md | When content belongs in a skill rather than CLAUDE.md |
| Settings reference | https://code.claude.com/docs/en/settings.md | `claudeMdExcludes`, `autoMemoryEnabled`, `autoMemoryDirectory` |
| Hooks reference | https://code.claude.com/docs/en/hooks.md | `InstructionsLoaded` hook for debugging |
| Sub-agents reference | https://code.claude.com/docs/en/sub-agents.md | Subagent persistent memory |

## Re-sync workflow

1. Refetch each upstream doc above (`ctx7 docs` or fresh download).
2. Diff against the assumptions encoded in this skill — surface table in SKILL.md, decision tree in routing.md, findings list in quality-criteria.md, "what earns its place" in update-guidelines.md.
3. Update the affected files; bump the `Last synced` date in the HTML comments at the top of each.
4. Update the date below.

## Last sync

- **Synced:** 2026-05-04
- **Memory doc revision:** matches https://code.claude.com/docs/en/memory.md as of this date
