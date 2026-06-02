# Audit Prompts (router)

Phase 4.5 spawns two audits in parallel — Codex (variant-specific) and Opus escalation (variant-agnostic). Compose the prompt files per this table:

| Plan shape | TDD? | Codex prompt | Escalation prompt |
|---|---|---|---|
| Single-file | No | `audit-prompt-single.md` | `audit-prompt-escalation.md` |
| Single-file | Yes | `audit-prompt-single.md` + `audit-prompt-tdd-additions.md` (renumbered to 7-11) | `audit-prompt-escalation.md` |
| Multi-file (agent-teams) | No | `audit-prompt-multifile.md` | `audit-prompt-escalation.md` |
| Multi-file (agent-teams) | Yes | `audit-prompt-multifile.md` + `audit-prompt-tdd-additions.md` (renumbered to 8-13) | `audit-prompt-escalation.md` |

Both audits always run in parallel. Escalation is variant-agnostic and never skipped except via the user opt-out documented in SKILL.md Phase 4.5.

## TDD-additions composition rules

When appending `audit-prompt-tdd-additions.md` to a base prompt:

- **Single-file TDD plans:** drop the "Test infra dependencies" bullet from the additions file (it only applies to multi-file plans).
- **Multi-file TDD plans:** keep all bullets.
- **Renumber** the TDD bullets to continue the base prompt's numbering — single: 7-11; multi-file: 8-13.

For the actual prompt body, see the per-prompt files referenced in this table. The escalation prompt is variant-agnostic and used as-is regardless of plan shape or TDD status.
