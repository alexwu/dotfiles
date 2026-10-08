# zmx — refresh this shell's terminal metadata from the attached client.
#
# A session shell outlives the terminal it started in. The session's host
# records the tracked variables (ZMX_TRACK_ENV, set in .zshenv) of the client
# that leads the session, and `bmx env -s .` prints them as export/unset lines.
# Running that before each prompt keeps WEZTERM_PANE, BTTY_PANE, SSH_AUTH_SOCK
# and the rest pointing at the terminal that is attached now. bmx asks a bmx
# host and a zmx daemon alike, and both set ZMX_SESSION.
#
# This updates the shell and the processes it starts afterwards. A process that
# is already running (a long-lived claude, nvim) keeps the env it was exec'd
# with; it has to ask for the live value: `bmx env . WEZTERM_PANE`.
#
# Without bmx the session is one `zn` hosted with zmx, and zmx is asked.
if [[ -n $ZMX_SESSION ]] && (($+commands[bmx] || $+commands[zmx])); then
  autoload -Uz add-zsh-hook

  if (($+commands[bmx])); then
    _zmx_tracked_env() { bmx env -s .; }
  else
    _zmx_tracked_env() { zmx print-env -s .; }
  fi

  _zmx_refresh_env() {
    # Later precmd hooks (p10k's status segment) read $?, so hand it back.
    local rc=$? out
    out=$(_zmx_tracked_env 2>/dev/null) && [[ -n $out ]] && eval "$out"
    return $rc
  }
  add-zsh-hook precmd _zmx_refresh_env
fi
