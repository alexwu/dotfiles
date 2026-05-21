# zmx shell integration & environment

How to wire zmx into your shell, prompt, and SSH workflow. Snippets are from the
zmx v0.6.0 README; the fzf picker is corrected for v0.6.0's `zmx list` field
names (see the note there).

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

## fzf session picker

An interactive picker that fuzzy-finds existing sessions, previews their
scrollback, or creates new ones — all from one prompt. Especially useful for SSH
workflows: add it to shell startup so connecting to a machine drops you straight
into the picker. Requires [fzf](https://github.com/junegunn/fzf).

- **Enter** — select the matched session (or create one if none exist).
- **Ctrl-N** — create a new session from the typed query, even when a fuzzy
  match is highlighted.
- **Ctrl-C** — cancel; drop into a regular shell as an escape hatch.

### bash / zsh

```bash
zmx-select() {
  local display
  display=$(zmx list 2>/dev/null | while IFS=$'\t' read -r name pid clients created dir; do
    name=${name##*name=}
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
    --preview='zmx history {1}' \
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

> The field-stripping above is corrected for zmx v0.6.0. The README's published
> version strips `session_name=` / `started_in=`, but v0.6.0 `zmx list` emits
> `name=` / `start_dir=`; `${name##*name=}` also drops the leading `→`/space
> prefix so the `--preview` and selection see a bare session name.

### Auto-launch on shell startup

Call `zmx-select` manually, bind it to a key, or auto-launch it when outside a
zmx session. With `&& exit`, the flow becomes: SSH in → pick a session → work →
detach or exit → SSH disconnects automatically.

```bash
if command -v zmx &> /dev/null && command -v fzf &> /dev/null && [[ -z "$ZMX_SESSION" ]]; then
  zmx-select && exit
fi
```

## SSH multi-window workflow

zmx's model: instead of one SSH connection with N tmux panes, open N terminals,
SSH into each, and attach a session per terminal. Your OS window manager
arranges them — that is the whole philosophy.

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

Logs are always on and cannot currently be disabled:

- Global CLI log: `{socket_dir}/logs/zmx.log`
- Per-session log: `{socket_dir}/logs/{session_name}.log`

`zmx version` prints the resolved socket and log directories — the quickest way
to confirm where everything lives.

## Permissions

Two environment variables set filesystem modes:

- `ZMX_DIR_MODE` — octal mode for the socket and log directories (default
  `0750`).
- `ZMX_LOG_MODE` — octal mode for the log files (default `0640`).

Useful when running zmx as a system service with a shared group — e.g.
`ZMX_DIR_MODE=0770` and `ZMX_LOG_MODE=0660` lets group members attach to the
session.
