# zmx shell integration & environment

How to wire zmx into your shell, prompt, and SSH workflow. Snippets track the
zmx **v0.7.0** README. Items marked **0.7.0+** are not available on 0.6.0.

## Contents

- [Prompt indicator](#prompt-indicator)
- [Shell completions](#shell-completions)
- [fzf session picker](#fzf-session-picker)
- [SSH multi-window workflow](#ssh-multi-window-workflow)
- [ZMX_SESSION_PREFIX](#zmx_session_prefix)
- [Socket directory & logs](#socket-directory--logs)
- [Permissions](#permissions)

## Prompt indicator

zmx gives no visual sign you are inside a session — only the `$ZMX_SESSION`
environment variable. Surface it in your prompt.

### fish — `~/.config/fish/config.fish`

```fish
functions -c fish_prompt _original_fish_prompt 2>/dev/null

function fish_prompt --description 'Write out the prompt'
  if set -q ZMX_SESSION
    echo -n "[$ZMX_SESSION] "
  end
  _original_fish_prompt
end
```

### bash / zsh — `.bashrc` or `.zshrc`

```bash
if [[ -n $ZMX_SESSION ]]; then
  export PS1="[$ZMX_SESSION] ${PS1}"
fi
```

### powerlevel10k — `.zshrc`

```bash
function prompt_my_zmx_session() {
  if [[ -n $ZMX_SESSION ]]; then
    p10k segment -b '%k' -f '%f' -t "[$ZMX_SESSION]"
  fi
}
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=my_zmx_session
```

### oh-my-posh

```toml
[[blocks.segments]]
   template = '{{ if .Env.ZMX_SESSION }} {{ .Env.ZMX_SESSION }}{{ end }}'
   foreground = 'p:orange'
   background = 'p:black'
   type = 'text'
   style = 'plain'
```

### Starship

```toml
format = """
${env_var.ZMX_SESSION}\
...
"""

[env_var.ZMX_SESSION]
symbol = " "
format = "[$symbol$env_value]($style) "
description = "zmx session name"
style = "bold magenta"
```

## Shell completions

`zmx completions <shell>` emits a completion script that completes both zmx
subcommands and live session names — and it works over SSH:

```bash
ssh remote-server zmx attach session-na<TAB>   # session names complete remotely
```

Homebrew installs completions automatically. Otherwise wire them up per shell.

### bash — `.bashrc`

```bash
if command -v zmx &> /dev/null; then
  eval "$(zmx completions bash)"
fi
```

### zsh — `.zshrc`

```zsh
if command -v zmx &> /dev/null; then
  eval "$(zmx completions zsh)"
fi
```

### fish — `~/.config/fish/completions/zmx.fish`

```fish
if type -q zmx
  zmx completions fish | source
end
```

### nushell (0.7.0+) — sourced from `config.nu`

`zmx completions nu` is new in 0.7.0; 0.6.0 accepts only `bash`, `zsh`, and
`fish`, and exits silently on anything else — so a `nu` completion that produces
no output means the binary is too old, not that the command failed.

```nu
zmx completions nu | save -f ~/.config/nushell/zmx-completions.nu
# then in config.nu:  source ~/.config/nushell/zmx-completions.nu
```

## fzf session picker

An interactive picker that fuzzy-finds existing sessions, previews their
scrollback, or creates new ones — all from one prompt. Especially useful for SSH
workflows: add it to shell startup so connecting to a machine drops you straight
into the picker. Requires [fzf](https://github.com/junegunn/fzf).

- **Enter** — select the matched session (or create one if none exist).
- **Ctrl-N** — create a new session from the typed query, even when a fuzzy
  match is highlighted.
- **Ctrl-C** — cancel; drop into a regular shell as an escape hatch.

> In this dotfiles setup `zmx-select` ships as a standalone script on `$PATH`
> (`~/.local/bin/zmx-select`, chezmoi source `dot_local/bin/executable_zmx-select`)
> rather than a per-shell function, so zsh and fish share one source. It draws
> its list from [`zmx-ps`](#) when present — richer rows (dir · state ·
> running · clients), directories shown relative to `~/Code` / `$HOME` (the
> chezmoi source dir renders as `dotfiles`), and the current-session filter
> keyed off zmx's own `→` marker — and falls back to the plain `zmx list` parse
> below when `zmx-ps` isn't installed. Sessions started in the current directory
> sort to the top, the rest grouped by directory; `zmx-select --here` narrows
> the list to `$PWD` only. The inline function below is the portable,
> dependency-free equivalent.

### bash / zsh

```bash
zmx-select() {
  local display
  display=$(zmx list 2>/dev/null | while IFS=$'\t' read -r name pid clients created dir; do
    name=${name##*name=}
    [[ -n "$ZMX_SESSION" && "$name" == "$ZMX_SESSION" ]] && continue   # hide the session you're already in
    pid=${pid#pid=}
    clients=${clients#clients=}
    dir=${dir#start_dir=}
    printf "%-20s  pid:%-8s  clients:%-2s  %s\n" "$name" "$pid" "$clients" "$dir"
  done)

  local output query key selected session_name
  output=$({ [[ -n "$display" ]] && echo "$display"; } | fzf \
    --print-query \
    --expect=ctrl-n \
    --height=80% \
    --reverse \
    --prompt="zmx> " \
    --header="Enter: select | Ctrl-N: create new" \
    --preview='zmx history {1} --vt' \
    --preview-window=right:60%:follow \
  )
  local rc=$?

  query=$(echo "$output" | sed -n '1p')
  key=$(echo "$output" | sed -n '2p')
  selected=$(echo "$output" | sed -n '3p')

  if [[ "$key" == "ctrl-n" && -n "$query" ]]; then
    session_name="$query"
  elif [[ $rc -eq 0 && -n "$selected" ]]; then
    session_name=$(echo "$selected" | awk '{print $1}')
  elif [[ -n "$query" ]]; then
    session_name="$query"
  else
    return 130
  fi

  zmx attach "$session_name"
}
```

> Upstream fixed its own picker's field parsing in v0.7.0 (#172), so the README
> now strips `name=` / `start_dir=` too. Two differences remain in the version
> above, both deliberate: `${name##*name=}` (greedy) also drops the leading
> `→`/space prefix so the `--preview` and the selection see a bare session name,
> and the `$ZMX_SESSION` guard hides the session you are already sitting in.
>
> **The `dir` column collects junk.** `read`'s *last* variable absorbs the rest
> of the line, tabs included — so `dir` is really `start_dir=…` plus any `cmd=`,
> `ended=`, `exit_code=`, and (on **0.7.0+**) every label. `${dir#start_dir=}`
> only strips the prefix. Sessions created with an explicit command already show
> this; labels make it routine. Add a trailing catch-all so `dir` stays clean:
>
> ```bash
> while IFS=$'\t' read -r name pid clients created dir rest; do
> ```
>
> and print `$rest` as its own column if you want the labels visible.

### Auto-launch on shell startup

Call `zmx-select` manually, bind it to a key, or auto-launch it when outside a
zmx session. With `&& exit`, the flow becomes: SSH in → pick a session → work →
detach or exit → SSH disconnects automatically.

```bash
if command -v zmx &> /dev/null && command -v fzf &> /dev/null && [[ -z "$ZMX_SESSION" ]]; then
  zmx-select && exit
fi
```

### Alternative: gentle hint (shared servers)

Auto-launching the picker on every connection is too aggressive on a box you SSH
into for quick one-off commands. Print a one-line reminder instead, and only when
sessions actually exist:

```bash
if command -v zmx &> /dev/null && [[ -z "$ZMX_SESSION" ]]; then
  count=$(zmx ls --short 2>/dev/null | wc -l)
  if [[ "$count" -gt 0 ]]; then
    echo "zmx: $count session(s) active — \`zmx-select\` to attach" >&2
  fi
fi
```

`--short` is doing real work here: it prints one bare name per line *and* stays
silent when there are no sessions, so `wc -l` gives a clean `0` instead of
counting the "no sessions found" line. Auto-launch for dedicated dev machines,
hint for shared servers.

## SSH multi-window workflow

zmx's model: instead of one SSH connection with N tmux panes, open N terminals,
SSH into each, and attach a session per terminal. Your OS window manager
arranges them — that is the whole philosophy.

To try it without touching your SSH config, pass `-t` so ssh allocates a TTY —
without it `zmx attach` has no PTY to take over:

```bash
ssh -t dev-box zmx attach default
```

For the real setup, put `RequestTTY yes` in the config entry below instead.

Create an SSH config entry for the remote dev host:

```bash
Host = d.*
    HostName 192.168.1.xxx

    RemoteCommand zmx attach %k
    RequestTTY yes
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlMaster auto
    ControlPersist 10m
```

`ControlMaster` multiplexes multiple PTY sessions over a single TCP connection.
Because `attach` is an upsert, each connect creates or attaches as needed:

```bash
ssh d.term
ssh d.irc
ssh d.pico
ssh d.dotfiles
```

Wrap with [`autossh`](https://linux.die.net/man/1/autossh) for connections that
auto-reconnect (e.g. after a laptop lid close):

```bash
autossh -M 0 -q d.term
```

```fish
abbr -a ash "autossh -M 0 -q"   # then: ash d.term
```

## ZMX_SESSION_PREFIX

`ZMX_SESSION_PREFIX` prefixes the session name for **every** command that
accepts one. With it set, every name you pass is silently rewritten.

```bash
export ZMX_SESSION_PREFIX="d."
zmx a runner   # ZMX_SESSION=d.runner
zmx a tests    # ZMX_SESSION=d.tests
zmx k tests    # kills d.tests
zmx wait       # suspends until all tasks prefixed with "d." are complete
```

This is also why sessions can appear "missing" from `zmx list` — they may exist
under a prefix set in a different shell.

## Socket directory & logs

Each session has its own Unix socket file. The socket directory is resolved in
priority order:

1. `ZMX_DIR` → the exact path given.
2. `XDG_RUNTIME_DIR` → `{XDG_RUNTIME_DIR}/zmx` (recommended on Linux, typically
   `/run/user/{uid}/zmx`).
3. `TMPDIR` → `{TMPDIR}/zmx-{uid}` (uid suffix for multi-user safety).
4. `/tmp/zmx-{uid}` — the default fallback.

Logs are always on and cannot currently be disabled. **The log directory moved
in 0.7.0** and is no longer derived from the socket directory:

| | 0.6.0 | 0.7.0+ |
|---|---|---|
| Resolution | `{socket_dir}/logs` | 1. `$ZMX_DIR/logs`<br>2. `$XDG_STATE_HOME/zmx/logs`<br>3. `$HOME/.local/state/zmx/logs`<br>4. `{TMPDIR}/zmx-{uid}` (only if `HOME` is unset) |
| Typical macOS path | `/var/folders/…/zmx-{uid}/logs` | `~/.local/state/zmx/logs` |

Files are the same either way: a global `zmx.log` plus one
`{session_name}.log` per session.

Note that `ZMX_DIR` still pins **both** directories, so it is the one setting
that behaves identically across versions. Everywhere else, read the path off
`zmx version` rather than assuming — it prints the resolved socket and log
directories and is the quickest way to confirm where everything actually lives:

```sh
zmx version | awk '/^log_dir/ {print $NF}'
```

## Permissions

Two environment variables set filesystem modes:

- `ZMX_DIR_MODE` — octal mode for the socket and log directories (default
  `0750`).
- `ZMX_LOG_MODE` — octal mode for the log files (default `0640`).

Useful when running zmx as a system service with a shared group — e.g.
`ZMX_DIR_MODE=0770` and `ZMX_LOG_MODE=0660` lets group members attach to the
session.
