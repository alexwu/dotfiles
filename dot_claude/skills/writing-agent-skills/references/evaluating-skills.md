# Evaluating Skill Output Quality

Triggering reliably is necessary but not sufficient — you also want to know the skill produces *good* output, across varied prompts and edge cases, **better than no skill at all**. Structured evals give you that feedback loop. Load this when a skill matters enough to measure, or when comparing two versions.

> **Opt-in step.** This harness spawns a baseline run *and* a with-skill run for every test case — real time and tokens. It is a deliberate choice, not an automatic part of authoring: offer it and confirm before scaffolding `evals/` or spawning runs.

## Designing test cases

A test case has three parts: a realistic **prompt**, a human-readable **expected output**, and optional **input files**. Store them in `evals/evals.json`:

```json
{
  "skill_name": "csv-analyzer",
  "evals": [
    {
      "id": 1,
      "prompt": "Monthly sales in data/sales_2025.csv — find the top 3 months by revenue and make a bar chart.",
      "expected_output": "A bar chart of the top 3 months by revenue, labeled axes and values.",
      "files": ["evals/files/sales_2025.csv"]
    },
    {
      "id": 2,
      "prompt": "csv in downloads called customers.csv, some rows missing emails — clean it and tell me how many were missing.",
      "expected_output": "A cleaned CSV with missing emails handled, plus the count missing.",
      "files": ["evals/files/customers.csv"]
    }
  ]
}
```

Tips:
- **Start with 2–3 cases.** Don't over-invest before the first round of results.
- **Vary prompts** — phrasing, detail, formality. Casual ("clean up this csv") alongside precise ("drop rows where column B is null, write to data/output.csv").
- **Cover an edge case** — malformed input, unusual request, ambiguous instruction.
- **Realistic context** — file paths, column names, personal framing. "Process this data" tests nothing.

Don't define pass/fail checks yet — just prompts and expected outputs. Assertions come after you see what the first run produces.

## Running evals

Run each case **twice**: once **with the skill**, once **without** (or against the previous version) — the baseline is what makes the delta meaningful.

### Workspace layout

Keep results in a workspace directory beside the skill; each pass gets its own `iteration-N/`:

```
csv-analyzer/
├── SKILL.md
└── evals/evals.json
csv-analyzer-workspace/
└── iteration-1/
    ├── eval-top-months-chart/
    │   ├── with_skill/    { outputs/, timing.json, grading.json }
    │   └── without_skill/ { outputs/, timing.json, grading.json }
    ├── eval-clean-missing-emails/  { ... }
    └── benchmark.json
```

You author `evals/evals.json` by hand; the `grading.json` / `timing.json` / `benchmark.json` files are produced during the process.

### Spawning runs

Each run starts with a **clean context** — no leftover state — so the agent follows only what `SKILL.md` says. Subagent-capable clients (Claude Code) give this naturally: each child task starts fresh. Otherwise use a separate session per run. Provide, per run: the skill path (or none for baseline), the prompt, input files, and the output directory.

```
Execute this task:
- Skill path: /path/to/csv-analyzer   (omit for the baseline run)
- Task: <the eval prompt>
- Input files: evals/files/sales_2025.csv
- Save outputs to: .../iteration-1/eval-top-months-chart/with_skill/outputs/
```

When improving an existing skill, snapshot the old version (`cp -r <skill> <workspace>/skill-snapshot/`), point the baseline at the snapshot, and save to `old_skill/outputs/`.

### Timing data

Record cost so you can weigh quality gains against token/time spend — a skill that triples tokens for a 2-point gain is a different trade than one that's better *and* cheaper:

```json
{ "total_tokens": 84852, "duration_ms": 23332 }
```

In Claude Code the subagent completion notification carries `total_tokens` and `duration_ms` — save them immediately; they aren't persisted elsewhere.

## Writing assertions

Verifiable statements about the output. Add them **after** the first round — you often don't know what "good" looks like until the skill has run.

- **Good:** "The output file is valid JSON" (programmatic), "The bar chart has labeled axes" (observable), "The report has ≥3 recommendations" (countable).
- **Weak:** "The output is good" (ungradeable), "uses exactly the phrase 'Total Revenue: $X'" (too brittle).

Not everything needs an assertion — writing style, visual polish, "feels right" are for human review. Reserve assertions for objective checks.

```json
"assertions": [
  "The output includes a bar chart image file",
  "The chart shows exactly 3 months",
  "Both axes are labeled",
  "The chart title or caption mentions revenue"
]
```

## Grading

Evaluate each assertion against actual outputs, recording PASS/FAIL **with concrete evidence** (quote/reference the output, not an opinion):

```json
{
  "assertion_results": [
    { "text": "includes a bar chart image", "passed": true,  "evidence": "Found chart.png (45KB) in outputs/" },
    { "text": "shows exactly 3 months",       "passed": true,  "evidence": "Bars for March, July, November" },
    { "text": "both axes labeled",            "passed": false, "evidence": "Y-axis 'Revenue ($)'; X-axis unlabeled" },
    { "text": "title mentions revenue",       "passed": true,  "evidence": "Title 'Top 3 Months by Revenue'" }
  ],
  "summary": { "passed": 3, "failed": 1, "total": 4, "pass_rate": 0.75 }
}
```

LLM grading works for judgment calls; for mechanical checks (valid JSON, correct row count, file exists with expected dimensions) use a **verification script** — more reliable than LLM judgment and reusable across iterations.

Principles:
- **Require concrete evidence for PASS** — no benefit of the doubt. A "Summary" heading with one vague sentence is a FAIL if the assertion wanted a real summary.
- **Review the assertions too** — flag ones that always pass (too easy), always fail (too hard / wrong target), or can't be checked from the output. Fix them for next iteration.
- **Blind comparison** for two versions: present both outputs to a judge without revealing which is which; score holistic qualities (organization, formatting, usability). Two outputs can pass all assertions yet differ in quality.

## Aggregating

Per-configuration summary in `benchmark.json`:

```json
{
  "run_summary": {
    "with_skill":    { "pass_rate": {"mean":0.83}, "tokens": {"mean":3800} },
    "without_skill": { "pass_rate": {"mean":0.33}, "tokens": {"mean":2100} },
    "delta":         { "pass_rate": 0.50, "tokens": 1700 }
  }
}
```

The **delta** is the point: what the skill costs (time, tokens) vs. what it buys (pass rate). +50 points for +13s is probably worth it; +2 points for 2× tokens probably isn't. `stddev` only means something with multiple runs per eval — in early single-run iterations focus on raw counts and the delta.

## Analyzing patterns

Aggregates hide things. After computing benchmarks:
- **Drop assertions that always pass in both** configs — the model handles them without the skill; they inflate the with-skill rate.
- **Investigate assertions that always fail in both** — broken assertion, too-hard case, or wrong target. Fix before next iteration.
- **Study assertions that pass with-skill but fail without** — this is where the skill adds value. Understand *why* (which instruction/script made the difference).
- **Tighten instructions on inconsistent results** (high stddev) — flaky eval or ambiguous instructions the model interprets differently each run. Add examples / specificity.
- **Read transcripts on time/token outliers** to find the bottleneck.

## Human review

Assertions only check what you thought to write. A human reviewer catches the unanticipated — technically correct but misses the point, or problems hard to express as pass/fail. Record specific, actionable feedback per case (`feedback.json`): "missing axis labels and months are alphabetical instead of chronological" is actionable; "looks bad" isn't. Empty feedback = the output looked fine. Review results **inline** rather than through a separate HTML editor — keeping outputs and grades in-context makes the next revision faster to reason about.

## Iterating

Three signals: **failed assertions** (specific gaps), **human feedback** (broader quality), **execution transcripts** (*why* it went wrong — ignored instruction → ambiguous; wasted steps → simplify/remove).

The efficient move: give all three plus the current `SKILL.md` to an LLM and ask for proposed changes, with these guardrails:
- **Generalize** — fix underlying issues broadly, not narrow patches for specific cases.
- **Keep it lean** — fewer better instructions win; if pass rates plateau as you add rules, the skill is over-constrained — try *removing* instructions.
- **Explain why** — "do X because Y causes Z" beats "ALWAYS do X." Models follow reasoned instructions more reliably.
- **Bundle repeated work** — if every run reinvents the same helper, bundle it (`using-scripts.md`).

The loop: propose → apply → rerun in a new `iteration-<N+1>/` → grade & aggregate → human review → repeat. Stop when satisfied, feedback is consistently empty, or improvement stalls.
