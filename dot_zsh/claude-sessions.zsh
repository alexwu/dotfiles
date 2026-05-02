# pick-claude-sessions: sk-backed picker for resuming Claude Code sessions.
#
# Replaces the earlier TV channel — TV's attach_to_tty hands the spawned
# child dup'd /dev/tty fds, which bun's kqueue rejects on Darwin
# (oven-sh/bun#24158). sk spawns claude as a plain child of this shell,
# so claude inherits our original pty slave fds and bun is happy.
#
# Bindings:
#   enter     resume in this shell (cd + claude --resume)
#   alt-f     resume + --fork-session  (branch into a new session id)
#   alt-w     resume + --worktree      (open in a new git worktree)
#   ctrl-z    open in a new zellij tab (only meaningful inside zellij)
#   ctrl-o    open the session jsonl in $EDITOR
#   ctrl-y    copy the full session UUID to the clipboard
#   ctrl-d    delete the session jsonl + sidechain dir, then refresh
#
# Mechanism for fork/worktree: sk's `accept(<token>)` action prints the
# token on the first line of stdout followed by the selected line, so the
# function can dispatch to the right subcommand and eval its output back
# in this shell (where claude needs to run).

if (( $+commands[sk] )) && (( $+commands[tv-claude-session] )); then
  pick-claude-sessions() {
    local clip
    if (( $+commands[pbcopy] )); then
      clip=pbcopy
    elif (( $+commands[wl-copy] )); then
      clip=wl-copy
    elif (( $+commands[xclip] )); then
      clip='xclip -selection clipboard'
    else
      clip='cat >/dev/null'
    fi

    local out
    out=$(tv-claude-session list | sk \
      --ansi \
      --reverse \
      --header 'enter=resume  alt-f=fork  alt-w=worktree  ctrl-z=zellij  ctrl-o=jsonl  ctrl-y=yank id  ctrl-d=delete' \
      --preview 'tv-claude-session preview {}' \
      --preview-window 'right:60%:wrap' \
      --bind 'alt-f:accept(fork)' \
      --bind 'alt-w:accept(worktree)' \
      --bind "ctrl-z:execute(eval \"\$(tv-claude-session resume-zellij {})\")+abort" \
      --bind "ctrl-o:execute(eval \"\$(tv-claude-session open {})\")" \
      --bind "ctrl-y:execute-silent(tv-claude-session id {} | $clip)" \
      --bind 'ctrl-d:execute(tv-claude-session delete {})+reload(tv-claude-session list)')

    [[ -z "$out" ]] && return 0

    local nlines key sel
    nlines=$(printf '%s' "$out" | grep -c '^')
    if (( nlines == 1 )); then
      eval "$(tv-claude-session resume "$out")"
    else
      key=${out%%$'\n'*}
      sel=${out#*$'\n'}
      case "$key" in
        fork)     eval "$(tv-claude-session resume --fork "$sel")" ;;
        worktree) eval "$(tv-claude-session resume --worktree "$sel")" ;;
        *)
          print -ru2 "pick-claude-sessions: unknown accept token '$key'"
          return 1
          ;;
      esac
    fi
  }
fi
