# zmx — parsing & filtering recipes

zmx has no `--json` output, so `jaq` is out. But `zmx list` and `zmx version`
are line-oriented and **tab-separated `key=value`** — `rg`, `cut`, and `awk`
parse them cleanly. Every recipe below is verified against real `zmx list`
output.

## The `zmx list` format

One line per session. The current session's line starts with `→ `; every other
line starts with two spaces. After that prefix come tab-separated `key=value`
fields — the first four always, the rest only when they apply:

```
  name=<name>	pid=<pid>	clients=<n>	created=<epoch>	start_dir=<dir>
→ name=<name>	pid=<pid>	clients=<n>	created=<epoch>	start_dir=<dir>	cmd=<cmd>
```

| Position | Field | When |
|---|---|---|
| `$1`–`$4` | `name` `pid` `clients` `created` | always |
| `$5` | `start_dir` | session recorded a working directory |
| then | `cmd` | session was created with an explicit command |
| then | `ended` `exit_code` | a `run` task has finished in that session |
| last | `<label>=<value>`… | **0.7.0+**, one per label, key-sorted |

- `clients` — attached-client count; `0` means detached / headless.
- `created` — Unix epoch **seconds** (not a human date).
- Positional `awk` on `$1`–`$5` is safe: everything optional is appended
  *after* `start_dir`, so labels never shift the leading columns. Anything past
  `$5` should be matched by key, not position.
- Unreachable sessions emit a different shape entirely —
  `name=… err=<ErrorName> status=<cleaning up|unreachable>` — with no `pid` or
  `clients`. Filters keyed on `clients=` skip these silently.

## Extracting one field

Every field is `key=value`, so `rg -o` plus `cut` pulls any column:

```sh
zmx list | rg -o 'name=[^\t]+'      | cut -d= -f2-   # session names
zmx list | rg -o 'start_dir=[^\t]+' | cut -d= -f2-   # working directories
zmx list | rg -o 'pid=[^\t]+'       | cut -d= -f2-   # pids
```

`[^\t]+` stops at the next tab (or end of line for the last field).
`cut -d= -f2-` keeps everything after the first `=`, so values containing `=`
survive intact.

## Filtering

`zmx list` is one line per session — filter with `rg` before extracting:

```sh
zmx list | rg 'clients=[1-9]'              # attached sessions only
zmx list | rg 'clients=0\b'                # detached / headless only
zmx list | rg 'start_dir=.*lulu-select'    # sessions started under a directory
zmx list | rg '^→'                         # the current session's line
zmx list | rg -c 'name='                   # count sessions
```

From inside a session, `$ZMX_SESSION` is the current name directly — no parsing
needed. From outside, extract it from the `→` line:

```sh
zmx list | rg '^→' | rg -o 'name=[^\t]+' | cut -d= -f2-
```

Chain a filter into name extraction to get a clean list to act on:

```sh
# Names of every detached session under cleverific/
zmx list | rg 'clients=0\b' | rg 'start_dir=.*cleverific' \
  | rg -o 'name=[^\t]+' | cut -d= -f2-
```

## Filtering by label (0.7.0+)

There is no `--where` — the flag is in zmx's help text but not in its argument
parser, so it is silently ignored and you get every session (see
`commands.md`). Labels are just more `key=value` fields, so the same `rg`
filters work, anchored on a tab to avoid matching a value substring:

```sh
zmx list | rg '\tstage=build\b'                  # one label
zmx list | rg '\tproject=zmx\b' | rg '\tenv=prd\b'   # AND two labels
zmx list | rg '\tstage=' | rg -o 'name=[^\t]+' | cut -d= -f2- | xargs zmx kill
```

> ⚠️ **Only `name`, `start_dir`, and `cmd` are reserved label keys.** Nothing
> stops `zmx set dev clients=0`, which appends a second `clients=0` field and
> makes that session a false positive for `rg 'clients=0\b'` while it is in
> fact attached. If you filter on structural fields *and* use labels, anchor
> the structural ones to their position instead:
> `zmx list | awk -F'\t' '$3 == "clients=0"'`.

## Feeding names back into zmx

`kill`, `wait`, and `tail` all take multiple session names, so pipe a filtered
name list through `xargs`:

```sh
# Wait on every session under a CI directory
zmx list | rg 'start_dir=.*ci-run' \
  | rg -o 'name=[^\t]+' | cut -d= -f2- | xargs zmx wait

# Kill every detached session under a directory
zmx list | rg 'start_dir=.*scratch' | rg 'clients=0\b' \
  | rg -o 'name=[^\t]+' | cut -d= -f2- | xargs zmx kill
```

For sessions sharing a name prefix you don't need this — `zmx kill "prefix.*"`
and `zmx wait "prefix.*"` match by prefix natively. The list-and-filter approach
is for filtering on **directory** or **client count**, which the `*` glob
cannot do.

> ⚠️ `xargs zmx kill` is destructive. Dry-run it first: drop the `| xargs zmx kill`
> tail and eyeball the names before committing.

## A readable table

The raw `key=value` lines are awkward to scan. This reformats them into aligned
columns and marks the current session with `*`.

**Portable (POSIX `awk`)** — computes each session's age inline, because the
macOS `awk` has no `strftime`:

```sh
zmx list | awk -F'\t' -v now="$(date +%s)" '
{
  cur  = ($0 ~ /^→/) ? "*" : " "
  name = $1; sub(/.*name=/, "", name)
  cl   = $3; sub(/clients=/, "", cl)
  t    = $4; sub(/created=/, "", t)
  age  = now - t
  a = (age < 3600) ? int(age/60) "m" : (age < 86400) ? int(age/3600) "h" : int(age/86400) "d"
  dir  = $5; sub(/start_dir=/, "", dir)
  printf "%s %-44s c=%-2s %4s  %s\n", cur, name, cl, a, dir
}'
```

Output: `* kanassan-magetta  c=1  1h  /Users/you` — marker, name, client count,
age, directory.

**With `gawk`** (`brew install gawk`) — `strftime` prints a real date instead of
a relative age, folding in what the "Humanizing `created`" recipe below does
separately. No `-v now=` needed:

```sh
zmx list | gawk -F'\t' '
{
  cur  = ($0 ~ /^→/) ? "*" : " "
  name = $1; sub(/.*name=/, "", name)
  cl   = $3; sub(/clients=/, "", cl)
  t    = $4; sub(/created=/, "", t)
  dir  = $5; sub(/start_dir=/, "", dir)
  printf "%s %-44s c=%-2s %s  %s\n", cur, name, cl, strftime("%Y-%m-%d %H:%M", t), dir
}'
```

Output: `* kanassan-magetta  c=1  2026-05-21 11:33  /Users/you`.

## Humanizing `created`

`created` is raw epoch seconds. To render real dates (macOS / BSD `date`):

```sh
zmx list | cut -f1,4 | while IFS=$'\t' read -r f1 f4; do
  name=${f1##*name=}
  printf '%-44s %s\n' "$name" "$(date -r "${f4#created=}" '+%Y-%m-%d %H:%M')"
done
```

`cut -f1,4` keeps the name and created fields; `${f1##*name=}` drops the leading
prefix. On **Linux (GNU `date`)** swap `date -r "$epoch"` for `date -d "@$epoch"`
— GNU `date -r` reads a file's mtime, not an epoch.

## Parsing `zmx version`

`zmx version` is also tab-separated `key<TAB>value` (with alignment padding).
`awk` with `$NF` (last field) is robust to the padding:

```sh
zmx version | awk '/^socket_dir/ {print $NF}'   # socket directory
zmx version | awk '/^log_dir/    {print $NF}'   # log directory
zmx version | awk '/^zmx/        {print $NF}'   # version string
```

Handy for jumping straight to the logs:

```sh
rg -i 'error|panic' "$(zmx version | awk '/^log_dir/{print $NF}')"/*.log
```

## Searching scrollback (`zmx history`)

`zmx history <session>` is plain terminal text — search it with `rg` like any
other output. Wrap it in `memo` so the full scrollback stays retrievable rather
than piping through `tail` (see `commands.md` for the snapshot caveat):

```sh
memo -- zmx history dev | rg -i 'error|warning'
```
