# Best Practices

How to write skills that are well-scoped, grounded, and effective. Load when drafting or substantially revising a skill body.

## Start from real expertise

The common failure mode is asking an LLM to generate a skill from its general training knowledge. The result is vague filler — "handle errors appropriately," "follow best practices" — instead of the specific API patterns, edge cases, and conventions that make a skill worth loading. Effective skills are grounded in **real expertise fed into the creation process**.

### Extract from a hands-on task

Drive a real task in conversation with an agent — giving context, corrections, and preferences — then extract the reusable pattern. Pay attention to:

- **Steps that worked** — the sequence that led to success.
- **Corrections you made** — where you steered the agent ("use X not Y," "check edge case Z").
- **Input/output formats** — what the data looked like going in and out.
- **Context you provided** — project facts, conventions, constraints the agent didn't already know.

### Synthesize from existing artifacts

When you already have a body of knowledge, feed the **project-specific material** (not generic articles) to an LLM and ask it to synthesize. Good sources:

- Internal docs, runbooks, style guides.
- API specs, schemas, configuration files.
- Code-review comments and issue trackers (recurring concerns, reviewer expectations).
- Version-control history — patches and fixes reveal patterns through what actually changed.
- Real failure cases and their resolutions.

A pipeline skill built from your team's actual incident reports beats one built from a generic "data engineering best practices" article — it captures *your* schemas, failure modes, and recovery procedures.

## Refine with real execution

The first draft usually needs work. Run the skill on real tasks and feed the results — **all of them, not just failures** — back in. Ask: what triggered false positives? What was missed? What can be cut?

Read **execution traces**, not just final outputs. Common signals:

- Agent tries several approaches before one works → instructions too **vague**.
- Agent follows instructions that don't apply to the current task → instructions too **broad / not conditional**.
- Agent thrashes between options → too many choices, **no clear default**.

Even a single execute-then-revise pass noticeably improves quality. Complex domains benefit from several.

## Spending context wisely

Once activated, the full `SKILL.md` body competes with conversation history, system context, and other active skills for the agent's attention. Every token earns its place.

### Add what the agent lacks; omit what it knows

For each piece of content ask: **"Would the agent get this wrong without this instruction?"** If no, cut it. Don't explain what a PDF is, how HTTP works, or what a migration does. Spend the budget on conventions, non-obvious edge cases, and which specific tool/API to use.

```
<!-- Too verbose — the agent already knows what soft deletes are -->
Soft deletion is a pattern where rows are marked deleted instead of being
removed. To exclude them, you filter on the deletion timestamp column...

<!-- Better — jumps straight to the project-specific fact -->
The `users` table uses soft deletes. Every query must include
`WHERE deleted_at IS NULL` or results include deactivated accounts.
```

If the agent already handles the whole task well **without** the skill, the skill may not be adding value — measure it (`evaluating-skills.md`).

### Design coherent units

Scoping a skill is like scoping a function: it should encapsulate one coherent unit of work that composes with others. Too narrow → many skills load for one task (overhead, conflicting instructions). Too broad → hard to activate precisely. "Query a database and format results" is one unit; adding "database administration" is doing too much.

### Aim for moderate detail

Overly comprehensive skills hurt — the agent struggles to extract what's relevant and chases instructions that don't apply. Concise stepwise guidance with a working example beats exhaustive documentation. When you're covering every edge case, ask whether the agent's own judgment handles most of them.

### Structure large skills with progressive disclosure

Keep `SKILL.md` under 500 lines / 5k tokens — just the core. Move depth into `references/`, and **tell the agent when to load each file**: "Read `references/api-errors.md` if the API returns non-200" beats "see references/ for details." On-demand loading is the whole point.

## Calibrating control

Match the specificity of an instruction to the **fragility** of the task.

### Match specificity to fragility

**Give freedom** when multiple approaches are valid. Explaining *why* beats rigid directives — an agent that understands the purpose makes better context-dependent calls:

```
## Code review process
1. Check all database queries for SQL injection (use parameterized queries)
2. Verify authentication on every endpoint
3. Look for race conditions in concurrent paths
4. Confirm error messages don't leak internal details
```

**Be prescriptive** when operations are fragile, consistency matters, or order is load-bearing:

```
## Database migration
Run exactly this sequence:

    just db-migrate --verify --backup

Do not modify the command or add flags.
```

Most skills mix both. Calibrate each section independently.

### Provide defaults, not menus

Pick a default; mention alternatives briefly.

```
<!-- Too many options -->
You can use tool A, B, C, or D...

<!-- Clear default with escape hatch -->
Use `rg` for content search. For structural/syntactic matches, use `ast-grep`.
```

### Favor procedures over declarations

Teach *how to approach a class of problems*, not *what to output for one instance*.

```
<!-- Specific answer — only useful for this exact task -->
Join `orders` to `customers` on `customer_id`, filter region='EMEA', sum amount.

<!-- Reusable method — works for any analytical query -->
1. Read the schema from references/schema.yaml to find relevant tables
2. Join via the `_id` foreign-key convention
3. Apply the user's filters as WHERE clauses
4. Aggregate numeric columns and format as a markdown table
```

Specific details (output templates, "never output PII," tool-specific calls) are still valuable — the *approach* should generalize even when individual details don't.

## Patterns for effective instructions

Reusable techniques. Use the ones that fit — not every skill needs all of them.

### Gotchas sections

The highest-value content in many skills: environment-specific facts that defy reasonable assumptions. Not general advice — concrete corrections to mistakes the agent **will** make otherwise:

```
## Gotchas
- The `users` table uses soft deletes. Queries must include
  `WHERE deleted_at IS NULL` or results include deactivated accounts.
- The user ID is `user_id` in the DB, `uid` in the auth service, and
  `accountId` in the billing API. All three are the same value.
- `/health` returns 200 whenever the web server is up, even if the DB is
  down. Use `/ready` to check full service health.
```

Keep gotchas **in `SKILL.md`** — the agent must read them before hitting the situation; in a reference it may not recognize the trigger to load it. When a correction comes up during use, add it here. This is the most direct way to improve a skill iteratively.

### Templates for output format

Agents pattern-match concrete structures better than prose. Short templates inline; long or conditional ones in `assets/`, referenced so they load only when needed.

```
## Report structure
Use this template, adapting sections as needed:

    # [Title]
    ## Executive summary
    [one paragraph]
    ## Key findings
    - Finding with supporting data
    ## Recommendations
    1. Specific actionable recommendation
```

### Checklists for multi-step workflows

Explicit checklists help the agent track progress and avoid skipped steps, especially with dependencies or validation gates:

```
## Form processing
- [ ] 1. Analyze the form (run `just analyze-form`)
- [ ] 2. Create field mapping (edit fields.json)
- [ ] 3. Validate mapping (run `just validate-fields`)
- [ ] 4. Fill the form (run `just fill-form`)
- [ ] 5. Verify output (run `just verify-output`)
```

### Validation loops

Have the agent check its own work before moving on: do the work → run a validator → fix → repeat until it passes.

```
## Editing workflow
1. Make your edits
2. Run validation: `just validate output/`
3. If it fails: read the error, fix, re-run
4. Proceed only when validation passes
```

A reference document can act as the validator — instruct the agent to check its work against it before finalizing.

### Plan-validate-execute

For batch or destructive operations, have the agent emit an intermediate plan, validate it against a source of truth, then execute:

```
## Form filling
1. Extract fields: `just analyze-form input.pdf` → form_fields.json
   (every field name, type, required-ness)
2. Author field_values.json mapping each field to its value
3. Validate: `just validate-fields form_fields.json field_values.json`
   (every name exists, types compatible, required present)
4. If validation fails, revise field_values.json and re-validate
5. Fill: `just fill-form input.pdf field_values.json output.pdf`
```

The load-bearing step is 3 — a validator that checks the plan against the source of truth. Errors like `Field 'signature_date' not found — available: customer_name, order_total, signature_date_signed` give the agent enough to self-correct.

### Bundling reusable scripts

When iterating, compare execution traces across runs. If the agent keeps **reinventing the same logic** (building a chart, parsing a format, validating output), that's the signal to write a tested helper once and bundle it. See `using-scripts.md` for the language policy and how to expose helpers as `just` recipes.
