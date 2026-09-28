# Scope Ledger

The ledger exists so a requested feature can't shrink quietly. Every item the user asked for, and every item raised during the session (in brainstorming, exploration, an audit, or a review), gets exactly one row. A row's **Home** says where that item will actually get done. There is no "later".

A long plan, several plans, or several phases are all fine. What's not fine is an item that was asked for and has no Home.

## Allowed Homes

| Home | Meaning | When |
|---|---|---|
| `Phase N` / `Steps N-M` / `Step N` / `Cycle N` / `Section N` | done in this plan | the default |
| `bd <prefix>-<id>` | a filed bead | after Phase 6 |
| `#123` / `owner/repo#123` | a filed GitHub issue | after Phase 6, only where the user approved GitHub issues |
| `handoff <file>` | written into a `.handoff/` doc | after Phase 6 |
| `to file: bead` / `to file: gh issue` / `to file: handoff` / `to file: next plan` | provisional; becomes one of the rows above in Phase 6 | during planning only |
| `dropped — "<the user's words>"` | the user dropped it, quoted verbatim | only with the user's own quote |

Anything else fails `check-plan`: `later`, `follow-up`, `TBD`, `future`, `v2`, `next PR`, `next session`, or a blank cell.

## Format

```markdown
## Scope Ledger

| # | Item | Source | Home | Status |
|---|---|---|---|---|
| 1 | Token bucket in `src/limiter.rs` | user: "rate limit the API with a token bucket" | Steps 1-3 | planned |
| 2 | Per-tenant limit overrides | user: "and per-tenant overrides" | Steps 4-5 | planned |
| 3 | Admin page to edit limits | user: "an admin page to tweak them" | to file: next plan | provisional |
| 4 | Limiter metrics to Prometheus | brainstorm: ops blind spot | bd tools-8k2 | filed |
| 5 | Redis-backed distributed bucket | escalation audit | dropped — "single-node is fine, we're not clustering this" | dropped |
```

- **Item** names one deliverable. Split "X and Y" into two rows.
- **Source** is a quote or a named origin: `user: "…"`, `brainstorm`, `exploration`, `Codex audit`, `escalation audit`, `review`. Never a paraphrase attributed to the user.
- **Status** is one of `planned`, `provisional`, `filed`, `dropped`, `done`.
- Rows are never deleted. When an item moves, rewrite its Home and update its Status.

## Rules

1. **Quote, don't paraphrase.** The plan's `## Requested Scope` quotes the user's actual words. Every distinct thing they asked for in those quotes becomes a row. A paraphrase is where items vanish.
2. **Ask where, never whether.** When an item turns out bigger than expected, the question is where it goes: this plan, a second plan, or a filed issue. Every option keeps the item. If you think it should be cut, say why and let the user drop it in their own words. That quote is the only thing that closes a row as `dropped`.
3. **The build order isn't the scope.** Sequencing the work (a thin end-to-end spine first, then the rest) is good planning. The rest still gets rows.
4. **Multi-plan features are normal.** When a feature needs more than one plan, the rows for the later slices read `to file: next plan`. Phase 6 either files them as a bead epic, or goes straight back into plan mode for the next slice.
5. **Provisional rows get filed before the session can end.** Phase 6 turns every `to file:` row into a real Home, then runs `check-plan --filed`. Filing finishes before any `/compact` or fresh-session handoff.

## Where filed rows go

Detect the tracker with `bd where`, not by looking for a `.beads/` directory. `bd` walks up parent directories, and in `eo` workspaces the store sits at the workspace root, one level above each repo worktree.

- **`bd where` exits 0:** file beads there.
- **`bd where` fails:** ask the user once, in Phase 3, where this repo's rows should go. Order the options by repo type:
  - Cleverific (`~/Code/cleverific/…`): run `bd init` at the workspace root (default), or a handoff doc. Never GitHub issues; employer repos don't get agent-filed issues.
  - Repos whose issue tracker is GitHub: a GitHub issue, `bd init`, or a handoff doc.
  - Everything else, including Forgejo-homed repos: `bd init` (default) or a handoff doc.

  Record the answer under `## User-Confirmed Decisions`.

## Where the ledger lives

- **Plan:** `## Scope Ledger`, required. `check-plan` validates every row; `check-plan --filed` runs after Phase 6.
- **Brainstorm recap:** the full table plus the user's original ask verbatim, carried into plan mode, or into a handoff doc if the session ends first.
- **Handoff doc:** `## Scope Ledger` with every row that isn't `done` or `dropped`.
- **Code review:** super-code-review's drift reviewer reads the plan's ledger and flags any planned row with no footprint in the diff.
