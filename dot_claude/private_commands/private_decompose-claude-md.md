---
description: Refactor an oversized CLAUDE.md by extracting sections into .claude/rules/ files; if the real source of truth is AGENTS.md, decompose it spatially into nested per-directory AGENTS.md files instead
allowed-tools: Skill, Read, Edit, Write, Glob, Grep, Bash
argument-hint: <path to CLAUDE.md or AGENTS.md> (defaults to ./CLAUDE.md)
---

<!--
Thin shim. The workflow lives in the `decompose-claude-md` SKILL so it deploys
cross-agent via run_onchange_deploy-agents-skills.sh.tmpl (Codex and lu see
skills, never .claude/commands/). Edit the skill, not this file.
Source: dot_claude/skills/exact_decompose-claude-md/SKILL.md
-->

Invoke the `decompose-claude-md` skill and follow it end to end.

Target file: $ARGUMENTS

`$ARGUMENTS` is substituted as literal text, so `${VAR:-default}` expansion doesn't apply. If the line above came through empty, skip it and use the skill's own Step 1 target resolution (which defaults to `./CLAUDE.md`).
