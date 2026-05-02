# Wrapper around `tv` that intercepts the `claude-sessions` channel only.
#
# Why: TV's `mode = "execute"` actions run inside a child shell that TV
# replaces itself with. When that child `cd`s into the session's cwd and
# execs `claude`, the parent shell never sees the cwd change — exiting
# claude leaves the user back in whatever directory they invoked `tv`
# from. Same reason `(cd /tmp)` doesn't move the parent.
#
# Pattern (mirrors zoxide's `z` function): the wrapper exports a path to
# a temp file via TV_CLAUDE_LAST_CWD, the Nim binary writes the resolved
# session cwd there before printing the eval'd shell command, and after
# `tv` exits the wrapper `cd`s into whatever's in the file.
#
# Other channels fall through unchanged via `command tv "$@"`.

if (( $+commands[tv] )); then
  tv() {
    if [[ "$1" == "claude-sessions" ]]; then
      local cwd_file
      cwd_file=$(mktemp -t tv-claude.XXXXXX) || {
        command tv "$@"
        return $?
      }
      TV_CLAUDE_LAST_CWD="$cwd_file" command tv "$@"
      local rc=$?
      if [[ -s "$cwd_file" ]]; then
        local target
        target="$(<"$cwd_file")"
        [[ -d "$target" ]] && cd -- "$target"
      fi
      rm -f "$cwd_file"
      return $rc
    else
      command tv "$@"
    fi
  }
fi
