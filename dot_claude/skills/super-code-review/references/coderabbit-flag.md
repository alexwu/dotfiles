# CodeRabbit Flag

The `--coderabbit` flag chains `coderabbit:code-review` after our Phase 1-5 pipeline finishes. **Off by default** per Alex's preference — only fires when explicitly requested.

## When to honor the flag

Run the CodeRabbit pass when any of these are true:

- The user passed `--coderabbit` as an argument
- The user said "with CodeRabbit", "also run CodeRabbit", "and CodeRabbit", or similar in their request
- The user said "all reviewers" / "everything you've got" / "max signal" (judgment call)

Do NOT auto-run CodeRabbit when:

- The user didn't mention it
- The user said "quick review" or "fast" (it's an extra round trip)
- The diff is working-tree mode (CodeRabbit primarily works on PRs — may be a no-op)

## Invocation

CodeRabbit ships as a skill (`coderabbit:code-review` and `coderabbit:coderabbit-review`):

```
Skill(
  skill: "coderabbit:code-review",
  args: "<args appropriate to the diff source>"
)
```

The skill's own logic handles the GitHub interaction. Pass the PR number or branch ref as appropriate. Check the skill's own docs (in `~/.claude/plugins/.../coderabbit/.../skills/code-review/SKILL.md`) for the exact args contract — it may have changed.

## Running it as Phase 6

CodeRabbit runs **after** Phases 1-5 complete, not in parallel. Reasons:

1. CodeRabbit's PR comments may already exist on the PR — running our review first lets us factor them out at dedupe
2. CodeRabbit is async — it queues a review and you wait — running parallel would block our output
3. Our review is the user's main signal; CodeRabbit is supplementary

Sequence at `--effort=high --coderabbit`:

```
Phase 1-2: Gather + fan-out (incl. Codex)         [parallel internally]
Phase 3:   Validate findings                       [parallel internally]
Phase 4:   Merge
Phase 5:   Output our review summary               [user sees this first]
Phase 6:   Invoke coderabbit:code-review
Phase 6.5: Append CodeRabbit's findings to output
```

The user sees our findings first; CodeRabbit's appear in an appended section so the order is clear.

## Output appending

After CodeRabbit completes, append a section to the output:

```
## CodeRabbit findings (additional pass)

<CodeRabbit's output, lightly reformatted to match our severity tags if possible>

---

Note: CodeRabbit reviews independently and may overlap with findings above.
```

Do NOT attempt to dedupe CodeRabbit findings against ours — they come from a different system with different conventions, and the user can compare visually. Pretending to merge them risks dropping signal.

## Mode-specific behavior

| Diff mode | CodeRabbit behavior |
|---|---|
| PR | Normal — CodeRabbit reviews the PR and returns its findings |
| Range (local branch ahead of main) | CodeRabbit may have nothing to say if there's no PR to comment on — surface that |
| Working-tree | CodeRabbit cannot review uncommitted changes — skip with a note in the output: "CodeRabbit skipped: requires a PR; working tree changes aren't reviewable" |

## Failure handling

If `coderabbit:code-review` returns an error or no findings:

- Note in the output: `(CodeRabbit pass was unavailable: <error>.)`
- Don't retry
- Don't fail the overall review — our findings are still the primary output

## Alex's preference summary

Quoted from his ask:
> "take advantage of code rabbit review, but that should be off my default, only if i request it for now"

So the default is unambiguous: **off**. Only honor when the user asks. Don't get cute about "you probably want it" — he'll ask when he wants it.
