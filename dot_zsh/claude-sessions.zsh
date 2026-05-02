# pick-claude-sessions: sk-backed picker for resuming Claude Code sessions.
#
# Replaces the earlier TV channel — TV's attach_to_tty hands the spawned
# child dup'd /dev/tty fds, which bun's kqueue rejects on Darwin
# (oven-sh/bun#24158). sk spawns claude as a plain child of this shell,
# so claude inherits our original pty slave fds and bun is happy.
#
# Bindings:
#   enter   resume in this shell  (cd + claude --resume)
#   ctrl-z  open in a new zellij tab (only meaningful inside zellij)
#   ctrl-o  open the session jsonl in $EDITOR
#   ctrl-d  delete the session jsonl + sidechain dir, then refresh the list

if (( $+commands[sk] )) && (( $+commands[tv-claude-session] )); then
  pick-claude-sessions() {
    local sel
    sel=$(tv-claude-session list | sk \
      --ansi \
      --reverse \
      --header 'pick a claude session  (enter=resume  ctrl-z=zellij tab  ctrl-o=open  ctrl-d=delete)' \
      --preview 'tv-claude-session preview {}' \
      --preview-window 'right:60%:wrap' \
      --bind 'ctrl-z:execute(eval "$(tv-claude-session resume-zellij {})")+abort' \
      --bind 'ctrl-o:execute(eval "$(tv-claude-session open {})")' \
      --bind 'ctrl-d:execute(tv-claude-session delete {})+reload(tv-claude-session list)')
    [[ -n "$sel" ]] && eval "$(tv-claude-session resume "$sel")"
  }
fi
