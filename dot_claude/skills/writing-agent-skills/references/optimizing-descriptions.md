# Optimizing Descriptions

A skill only helps if it activates. The `description` carries the **entire** triggering burden — at startup the agent loads only `name` + `description` and decides from those alone whether to read the body. Under-specified → it won't fire when it should. Over-broad → it fires when it shouldn't. Load this when a skill triggers too rarely, too often, or you're hardening a new description.

> **Opt-in step.** Writing a good description (below) is always worthwhile. *Running* the formal trigger-rate loop spawns many agent runs and spends real time and tokens — offer it and confirm before kicking it off; don't run it as a default part of authoring.

One nuance: agents typically consult a skill only for tasks needing capability beyond what they can do alone. A trivial "read this PDF" may not trigger a PDF skill even on a perfect description, because the agent handles it with basic tools. Specialized knowledge — an unfamiliar API, a domain workflow, an uncommon format — is where a good description earns its keep.

## Writing effective descriptions

- **Imperative phrasing.** "Use this skill when…" not "This skill does…". The agent is deciding whether to *act*.
- **User intent, not implementation.** Describe what the user is trying to achieve; the agent matches against the request, not your internals.
- **Be pushy.** Explicitly list contexts where it applies, including ones where the user doesn't name the domain: "even if they don't say 'CSV' or 'analysis'."
- **Concise.** A few sentences to a short paragraph. Hard limit **1024 chars** — and descriptions tend to grow during optimization, so re-check.

Before → after:

```yaml
# Before
description: Process CSV files.

# After
description: >
  Analyze CSV and tabular data — compute summary statistics, add derived
  columns, generate charts, clean messy data. Use when the user has a CSV,
  TSV, or Excel file and wants to explore, transform, or visualize it, even
  if they don't explicitly mention "CSV" or "analysis."
```

More specific about *what* (stats, columns, charts, cleaning), broader about *when* (CSV/TSV/Excel; no explicit keyword required).

## Designing trigger eval queries

Build a set of realistic prompts labeled with whether they *should* trigger:

```json
[
  { "query": "spreadsheet in ~/data/q4.xlsx, revenue in col C, expenses in D — add a profit-margin column and flag anything under 10%", "should_trigger": true },
  { "query": "quickest way to convert this json file to yaml?", "should_trigger": false }
]
```

Aim for ~20: 8–10 should-trigger, 8–10 should-not.

**Should-trigger** — vary along axes:
- *Phrasing*: formal, casual, typos, abbreviations.
- *Explicitness*: some name the domain ("analyze this CSV"), some don't ("my boss wants a chart from this data file").
- *Detail*: terse vs. context-heavy (file paths, column names, backstory).
- *Complexity*: single-step and multi-step, including the relevant task buried inside a larger chain.

The most useful positives are ones where the skill helps but the connection **isn't obvious from the query** — that's where wording makes the difference. If the query already asks for exactly what the skill does, any description triggers.

**Should-not-trigger** — the valuable ones are **near-misses** that share keywords but need something different:
- Weak: "Write a fibonacci function" (tests nothing), "What's the weather?" (no overlap).
- Strong: "update the formulas in my Excel budget spreadsheet" (shares "spreadsheet" but needs Excel editing), "script that reads a csv and uploads each row to postgres" (involves CSV but is DB ETL, not analysis).

**Realism:** include file paths, personal context ("my manager asked…"), specific names/values, casual language and occasional typos. Generic "process this data" tests nothing.

## Measuring trigger rate

Run each query through the agent with the skill installed and observe whether it invokes the skill (check the client's logs / tool-call history). A query **passes** when `should_trigger` matches the observed behavior.

Model behavior is nondeterministic — run each query **3×** and compute a **trigger rate** (fraction of runs that invoked it). A should-trigger query passes if rate > **0.5**; a should-not passes if rate < 0.5.

Script it. This bash harness uses Claude Code's JSON output and `jaq`; swap the `claude` call + detection for your client. Wrap it as a `just` recipe so it's one invocation:

```bash
# justfile recipe: `just eval-triggers queries.json`
queries="${1:?usage: eval-triggers <queries.json>}"
skill="my-skill"; runs=3

triggered() {  # 0 if the skill was invoked, 1 otherwise
  claude -p "$1" --output-format json 2>/dev/null \
    | jaq -e --arg s "$skill" \
      'any(.messages[].content[]; .type=="tool_use" and .name=="Skill" and .input.skill==$s)' \
      >/dev/null 2>&1
}

count=$(jaq length "$queries")
for i in $(seq 0 $((count-1))); do
  q=$(jaq -r ".[$i].query" "$queries")
  want=$(jaq -r ".[$i].should_trigger" "$queries")
  hits=0
  for _ in $(seq 1 $runs); do triggered "$q" && hits=$((hits+1)); done
  jaq -n --arg q "$q" --argjson want "$want" --argjson hits "$hits" --argjson runs "$runs" \
    '{query:$q, should_trigger:$want, hits:$hits, runs:$runs, rate:($hits/$runs)}'
done | jaq -s '.'
```

If the client can stop a run once the outcome is clear (skill consulted, or work started without it), do — it cuts cost sharply.

## Train / validation split (avoid overfitting)

Optimizing against *all* queries risks a description that fits these phrasings but fails new ones. Split:

- **Train (~60%)** — find failures, guide changes.
- **Validation (~40%)** — set aside, only check whether changes generalize.

Keep a proportional mix of positives/negatives in both. Shuffle once, keep the split fixed across iterations so comparisons are apples-to-apples. Two files (`train_queries.json`, `validation_queries.json`), run the harness against each.

## The optimization loop

1. **Evaluate** on train and validation. Train guides changes; validation tells you if they generalize.
2. **Identify train failures** — should-trigger that didn't, should-not that did. (Use *train* failures only — keep validation out of the loop.)
3. **Revise**, generalizing:
   - Positives failing → too narrow. Broaden scope / add when-useful context.
   - Negatives false-firing → too broad. Add specificity about what it does *not* do, or clarify the boundary with adjacent skills.
   - **Don't** paste keywords from failed queries — that's overfitting. Find the general category they represent and address that.
   - Stuck after a few iterations? Try a structurally different framing, not incremental tweaks.
   - Re-check the 1024-char limit.
4. **Repeat** until train passes or improvement stalls.
5. **Select by validation pass rate** — the best description may be an earlier iteration, not the last (later ones can overfit).

Five iterations is usually enough. If it won't improve, suspect the queries (too easy/hard/mislabeled), not the description.

## Applying the result

1. Update `description` in the frontmatter.
2. Confirm ≤1024 chars.
3. Sanity-check: try a few prompts manually, then 5–10 **fresh** queries (never used in optimization) for an honest generalization check.

Review eval results **inline** in the conversation — don't route them through a separate HTML report/editor; keeping the eval set and outcomes in-context is faster to reason about and revise.
