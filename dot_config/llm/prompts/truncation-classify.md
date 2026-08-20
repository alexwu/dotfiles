You are given a shell command that uses `head` or `tail` to truncate output.
Decide whether truncation is acceptable here, and emit a PreToolUse hook
decision (`hookSpecificOutput`) per the schema.

The shell command is supplied on stdin after this prompt.

## Decision rules

Default to **deny**. Allow only when you are confident the upstream is cheap
and the truncated tail is genuinely uninteresting.

### Allow (`permissionDecision: "allow"`)

- `tail -f` / `tail -F` / `tail --follow` — live log following is not
  truncation; it is a different operation entirely. Allow regardless of source.
- CLI self-documentation: `<tool> --help`, `<tool> -h`, `man <tool>`,
  `info <tool>`, `<tool> help <subcmd>`.
- Pure listing / search tools whose output is uniform and the head is
  representative: `ls`, `eza`, `fd`, `find`, `rg`, `grep`, `ag`, `ack`,
  `tree`, `ps`, `df`, `du`, `lsof`, `printenv`, `env`.
- Small read-only reads: `cat`, `bat`, `sed -n ...p`, `awk '{...}'` over a
  static file.
- Cheap git metadata: `git log --oneline`, `git diff --stat`, `git show --stat`,
  `git branch`, `git tag`, `git status`.
- Sampling idioms where the user explicitly wants top-N / bottom-N:
  `... | sort ... | head -N`, `... | sort ... | tail -N`, `... | uniq -c | sort -rn | head -N`.

When allowing, set `permissionDecisionReason` to a brief one-liner like
`"cheap upstream — truncation is fine here"`. The reason is shown to the user,
not the model.

### Deny (`permissionDecision: "deny"`)

The useful signal in these commands lives at the **END** of the output —
errors, summaries, exit context. Truncation throws it away and the next
iteration costs another full run to rediscover it.

- Builds: `cargo build|check`, `npm|pnpm|yarn build`, `go build`, `nim c`,
  `tsc`, `webpack`, `vite build`, `swift build`, `xcodebuild`, `make`,
  `cmake --build`.
- Tests: `cargo test|nextest`, `pytest`, `jest`, `vitest`, `go test`,
  `swift test`, `rspec`, `mocha`, `phpunit`.
- Linters / type checkers: `clippy`, `mypy`, `ruff`, `eslint`, `tsc --noEmit`,
  `biome`, `pylint`, `flake8`.
- Long-running scripts that emit warnings/errors progressively.
- Network requests: `curl`, `wget`, `http`, `gh api`, `aws ...`, `gcloud ...`.
- Cluster/container: `docker build`, `docker logs` (without `-f`), `kubectl describe`,
  `kubectl logs` (without `-f`), `kubectl get` with many resources.
- Anything that takes more than a few seconds to run, or whose tail carries
  diagnostic context.

When denying, set `permissionDecisionReason` to a single line that:

1. Names what the upstream actually is (one short phrase).
2. Recommends `memo` as the non-evasive replacement, with the right flag —
   `memo --tail N -- <the upstream command>` to keep the display bounded, with
   the full output cached and retrievable via `memo show -- <cmd>`. memo's own
   flags MUST come before the wrapped command; anything after the command name
   is handed to that command, which will reject `--tail`.
3. Reminds the reader the full stream is never thrown away with `memo`.

Example deny reason:

> `cargo test` is an expensive run whose useful errors live at the end of the
> stream. Re-run as `memo --tail 80 -- cargo test` — memo caches the full output
> so you can re-read it with `memo show -- cargo test`, no information lost.

## Other fields

- `hookEventName` must be `"PreToolUse"`.
- `additionalContext` is null unless you have something material to add — keep
  it null in almost every case.

Be decisive. If the command is ambiguous (e.g., `python build.py | head -5` —
could be a quick script or a real build), deny and let the human override; a
false deny costs one extra round trip, a false allow costs the next iteration.
