# pueue recipes

Concrete patterns Claude can copy-paste-adapt. All examples assume the macOS Homebrew install on this machine (`pueue 4.0.4` at `/opt/homebrew/bin/pueue`) and the Claude labeling convention.

## Long download (hf, ollama, curl, aria2)

```bash
TASK=$(pueue add --print-task-id \
  --label "claude: dl-llama-3.2-70b" \
  -- hf download meta-llama/Llama-3.2-70B-Instruct)
echo "Queued as task $TASK. Tail with: pueue follow $TASK"
```

For curl/wget:

```bash
pueue add --label "claude: dl-foo" \
  -- curl -fL --retry 3 -o /tmp/foo.tar.gz https://example.com/foo.tar.gz
```

For ollama:

```bash
pueue add --label "claude: ollama-pull-llama3" -- ollama pull llama3:70b
```

## Long build (Swift, Cargo, pytest)

```bash
# Swift Package Manager
pueue add --label "claude: ios-build" -w "$HOME/Code/lulu-app" \
  -- swift build

# Xcode — note the single-string form: the -destination value has a space, which breaks
# the `--` + argv form (pueue joins argv with spaces and the outer shell loses the quoting).
# See pitfalls-and-debugging.md, footgun #1 ("the sh -c quoting trap").
pueue add --label "claude: xcode-build" -w "$HOME/Code/lulu-app" \
  'xcodebuild -scheme MyApp -destination "platform=iOS Simulator,name=iPhone 15" build'

# Cargo
pueue add --label "claude: cargo-build" -w "$HOME/Code/myrust" \
  -- cargo build --release

# pytest
pueue add --label "claude: pytest" -w "$HOME/Code/myproject" \
  -- pytest -x --timeout=300
```

## Build → test DAG (test runs only if build succeeds)

```bash
BUILD=$(pueue add --print-task-id --label "claude: build" \
  -w "$HOME/Code/lulu-app" -- swift build)

pueue add --label "claude: test" --after "$BUILD" \
  -w "$HOME/Code/lulu-app" -- swift test
```

If `BUILD` fails, the test task auto-fails (status `Done` with `result: "DependencyFailed"`) and never runs. Pull logs with `pueue log $BUILD --full` to see why.

## Download → verify → unpack → import (4-step pipeline)

```bash
DL=$(pueue add --print-task-id --label "claude: dl" \
  -- curl -fL -o /tmp/dataset.tar.gz https://example.com/dataset.tar.gz)

VERIFY=$(pueue add --print-task-id --label "claude: verify" --after "$DL" \
  'cd /tmp && sha256sum -c dataset.tar.gz.sha256')

UNPACK=$(pueue add --print-task-id --label "claude: unpack" --after "$VERIFY" \
  -- tar -xzf /tmp/dataset.tar.gz -C /tmp/dataset)

pueue add --label "claude: import" --after "$UNPACK" \
  -w "$HOME/Code/myproject" -- python import_data.py /tmp/dataset
```

`pueue status` shows the chain with `Deps:` annotations.

## Synchronous wrapper (Claude needs the output inline)

When the user wants results immediately and is willing to wait:

```bash
TASK=$(pueue add --print-task-id --label "claude: sync-build" -w "$(pwd)" -- swift build)
pueue wait "$TASK" --quiet
pueue log "$TASK" --full
```

What you get: telemetry/persistence/logs as a side effect of pueue, but stdout flows back to Claude as if the command ran inline. Useful when you want pueue's recovery story without losing immediate-feedback UX.

## Pick up where we left off (cross-session)

```bash
pueue status --json | jaq -r '
  .tasks | to_entries[]
  | select(.value.label // "" | startswith("claude:"))
  | "\(.key)\t\(.value.label)\t\(.value.status | if type=="object" then keys[0] else . end)"
'
```

For a failed task, fetch its log first:

```bash
pueue log <id> --full
```

Decide:
- **Persistent failure** (bad command, missing input, schema bug) → tell the user, don't auto-retry.
- **Transient** (OOM, network blip, killed) → `pueue restart --in-place <id>`.

## Set up parallel groups for batching

```bash
# Downloads: 2 concurrent (don't saturate bandwidth)
pueue group add downloads
pueue parallel 2 --group downloads

# Builds: 4 concurrent (CPU-bound, plenty of cores)
pueue group add builds
pueue parallel 4 --group builds

# Submit a fan-out
for url in "$@"; do
  pueue add --group downloads --label "claude: dl-$(basename "$url")" -- curl -fLO "$url"
done
```

## Hyperparameter sweep with stashed env injection

```bash
pueue group add sweeps
pueue parallel 2 --group sweeps

for lr in 0.001 0.0005 0.0001; do
  TASK=$(pueue add --stashed --print-task-id \
    --group sweeps \
    --label "claude: train-lr-$lr" \
    -w "$HOME/Code/myml" -- python train.py)
  pueue env set "$TASK" LR "$lr"
  pueue env set "$TASK" RUN_NAME "lr_$lr"
  pueue enqueue "$TASK"
done
```

`pueue env set` requires the task to be stashed (or queued) — that's why `--stashed` + explicit `enqueue` is the pattern, not `pueue add` followed by `env set`.

## Wait for a whole group, then run a finalizer

```bash
# Inline (blocks the current shell)
pueue wait --group sweeps --quiet
pueue add --label "claude: aggregate" \
  -w "$HOME/Code/myml" -- python aggregate_runs.py
```

Or auto-chain by capturing all the IDs and `--after`-ing them:

```bash
IDS=()
for lr in 0.001 0.0005 0.0001; do
  T=$(pueue add --print-task-id --group sweeps --label "claude: train-$lr" \
    -- python train.py --lr "$lr")
  IDS+=("$T")
done

pueue add --after "${IDS[@]}" --label "claude: aggregate" \
  -w "$HOME/Code/myml" -- python aggregate_runs.py
```

## Quick smoke test (verify daemon + skill setup)

```bash
# Single-string form because the body has `&&`. See pitfalls footgun #1.
TASK=$(pueue add --print-task-id --label "claude: smoke-test" \
  'sleep 3 && echo "pueue is alive"')
pueue wait "$TASK" --quiet
pueue log "$TASK" --full
```

## Interactive picker (fzf integration from upstream wiki)

The pueue wiki documents a `pueue-fzf` script for interactive task management. Useful when the user wants to "show me what's running" with arrow-key navigation:

```bash
# Outline (full script in pueue wiki: Advanced-usage)
pueue status --json \
  | jaq -r '.tasks | to_entries[]
            | "\(.key)\t\(.value.label // "(no label)")\t\(.value.status | if type=="object" then keys[0] else . end)"' \
  | fzf --preview 'pueue log $(echo {} | cut -f1) --full | bat --color=always -p' \
        --bind 'ctrl-k:execute(pueue kill $(echo {} | cut -f1))' \
        --bind 'ctrl-r:execute(pueue restart --in-place $(echo {} | cut -f1))'
```

Don't run this unattended — it's an interactive UX, not a programmatic operation.
