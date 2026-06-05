---
name: super-brainstorming
description: Use when presenting a substantive, buildable idea — a new tool, app, system, library, or multi-component feature you can already describe in broad strokes — and you want to develop it into a concrete design and architecture before implementation. This is a design partnership for a technical user, NOT requirements hand-holding: pin down the architecture and component boundaries, the source of truth and data model, the interfaces between pieces, what to build first, what each part must do, and — critically — surface what hasn't been considered (failure modes, sync/concurrency, schema evolution, edge cases). Triggers on inputs like "I want to build a clipboard-history app in Rust with one source of truth and multiple clients (CLI, mac app)" — a clear concept whose design still needs nailing down. NOT for small or single-step changes, bug fixes, pure questions, or specs already concrete enough to implement directly — those go straight to plan-mode-plans / EnterPlanMode, which this skill hands off to once the design is settled.
---

# Super Brainstorming

## What this is

A **design and architecture partnership**. The user arrives with a real, articulable idea — they know roughly *what* they want to build. Your job is to turn that into a concrete design: the architecture, the component boundaries, the data model and source of truth, the interfaces between pieces, the build order, what each part must do — and to **proactively surface the things they haven't thought about**.

The user is a skilled engineer who brought a real idea — treat them as a peer, not someone who needs coaxing toward what they want. But **purpose, use case, and "why this way" are still first-class questions** — "what are you actually trying to solve here," "who's the user and what's the primary use case," "why X over Y" — because the answers genuinely shape the design (a clipboard app for fast paste-reuse vs. a searchable audit trail are different architectures). Ask them; just ask as a peer probing the design space, not as a requirements-gathering ritual that belabors the obvious. Bring architectural judgment on top.

**The deliverable is a settled design**, signed off by the user, handed to `plan-mode-plans` (via `EnterPlanMode`) for implementation planning. **No spec file** — the design lives in the conversation and gets captured by plan mode's Goal / Context / Decisions. Do not write `docs/specs/*` or any standalone design doc.

## When this fires vs. when to skip

| Signal | Action |
|---|---|
| "I want to build [tool/app/system] that [rough contours]" — concept clear, design open | **Brainstorm** |
| New system with multiple components / clients / layers to fit together | **Brainstorm** |
| Substantial feature with real architectural decisions (data model, boundaries, sequencing) | **Brainstorm** |
| Small or single-step change, clear how to do it | Skip → just do it |
| Bug fix / debugging | Skip → `systematic-debugging` |
| Pure question / lookup | Skip → just answer |
| Design already concrete enough to implement | Skip → `EnterPlanMode` (`plan-mode-plans`) |

The bar is **buildable idea + open design**, not "request is vague." A vague *small* ask gets one clarifying question inline, not this skill.

## The seam with `plan-mode-plans`

- **Super-brainstorming decides the design:** architecture, component boundaries, data model, interfaces, build order, per-component responsibilities, and the blind spots. Conceptual and structural. **Pre-exploration** (light orientation only).
- **plan-mode-plans turns the chosen design into a file-level plan:** exact paths, code snippets, ordered steps. **Post-exploration.**

If a question is "which architecture / what's the source of truth / what do we build first," it's here. If it's "which function, which file, what's the exact diff," that's plan mode.

## Process

### 1. Ground the idea

Restate what they want to build in your own words — one or two sentences — so the target is shared and any misread surfaces immediately. If it touches existing code, do a *light* orientation (recent commits, the obvious relevant files) to ask sharper questions. This is not the deep exploration plan mode does.

### 2. Clarify the design-determining forks

Ask focused questions, **one concept per round** (occasionally a tight cluster when genuinely independent), and keep going until the design space is pinned. Prefer `AskUserQuestion` with concrete options — discrete forks are faster to answer and force you to actually enumerate the choices. Lead with your recommendation.

Aim questions at decisions that **change the architecture**, e.g.:
- **Purpose & use case** — what's the core problem this solves, who uses it, what's the primary workflow? This isn't box-ticking — the answer routinely flips the design (a clipboard tool for fast paste-reuse wants a small ring buffer; one for a searchable audit trail wants a real indexed store). When a "why X over Y" is load-bearing, ask it.
- **Scope boundaries** — what's in v1 vs. later? (YAGNI — push back on everything not justified for the first working version.)
- **Hard constraints** — platforms, performance targets, dependencies, deployment, compatibility.
- **The forks that fan out** — the choices that, once made, determine everything downstream (for a multi-client app: where the source of truth lives and how clients talk to it).

Don't ask what you can reasonably decide and propose yourself — bring a recommendation and let them veto.

### 3. Drive the design

This is the heart of the skill. Actively propose and refine, don't just transcribe:

- **Architecture & boundaries** — name the components, what each one owns, how they communicate. Each unit should have one clear responsibility and a well-defined interface — something you can describe, use, and test without reading its internals.
- **Source of truth & data model** — what the canonical state is, where it lives, its shape. For multi-client / multi-process systems this is usually *the* decision everything hinges on — settle it early.
- **Interfaces / contracts** — how the pieces talk (API, IPC, schema, events). Define these before internals.
- **Build sequencing** — what comes first, what unblocks what. Identify the thinnest end-to-end slice that proves the architecture (the MVP spine), then what layers on.
- **Per-component responsibilities** — what each piece must be able to do.

Where there's a genuine architectural fork (e.g. socket vs. shared DB vs. message bus for client↔core), present 2-3 options with honest trade-offs and a recommendation grounded in their constraints. Don't manufacture alternatives when one path is clearly right.

### 4. Surface the blind spots

Explicitly part of the value — the user is counting on you to raise what they haven't. Pressure-test the design for:
- **Concurrency & sync** — race conditions, conflicting writes, ordering, multiple clients mutating shared state.
- **Failure modes** — what happens when the core is down, a client crashes mid-write, the store is corrupt, the network drops.
- **Schema / data evolution** — how state migrates as the design grows; versioning.
- **Lifecycle & ops** — startup/shutdown, where data lives, backups, upgrades.
- **Security & trust boundaries** — who can read/write, sensitive data at rest, IPC authentication.
- **Edge cases & scale** — empty/huge/malformed inputs, growth over time.

Call these out as you go, not as an afterthought. A raised concern either becomes a decision or an explicit known-risk.

### 5. Converge and hand off

Recap the settled design: the one-line goal, the architecture and component responsibilities, the source-of-truth/data-model decision, the build sequence (what's first), resolved decisions with rationale, and any known open risks. Get the user's nod.

Then **transition to plan mode** — `EnterPlanMode`, which loads `plan-mode-plans` — carrying the recap so its Scope / Decisions / Approach start from the settled design instead of re-deriving it. The recap is the breadcrumb; there's no spec file. Hand off ONLY to `plan-mode-plans`; do not invoke implementation skills or start editing code.

## Anti-patterns

| Red flag | Why it's wrong | Fix |
|---|---|---|
| Treating purpose questions as a hand-holdy ritual | Asking "what problem / who's the user / why X" is good and design-shaping — the failure is the condescending tone, not the question | Ask purpose/use-case/why as a peer probing the design, then move to structure |
| Skipping purpose entirely and jumping straight to boxes-and-arrows | You can architect the wrong thing fast | Pin down what it's for and the primary use case first — they constrain the design |
| Just transcribing what the user says into a design | They came for your architectural judgment | Propose structure, boundaries, sequencing; recommend |
| Skipping the source-of-truth/data-model decision | For multi-component systems it determines everything | Settle it early in step 3 |
| Leaving out blind spots to seem agreeable | Surfacing the unconsidered IS the value | Pressure-test concurrency, failure, evolution, security |
| Designing the whole v2 | Scope creep at design time is the most expensive kind | YAGNI — find the MVP spine first |
| Firing on a small/clear change | This skill is for buildable ideas with open design | One inline question, or just do it |
| Asking file-level / code-level questions here | That's `plan-mode-plans` Phase 3 | Decide architecture & order; defer the diff |
| Writing a `docs/specs/*.md` design file | This setup rejects rogue spec docs | Recap in conversation; let plan mode capture it |
| Handing off before the user confirms the design | You might've designed the wrong thing | Get the nod in step 5 first |
